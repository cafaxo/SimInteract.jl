struct SimulationResult{S,P}
    state::S
    parameters::P
end

mutable struct SimulationInstance{SIM,S,P}
    const simulator::SIM
    is_being_worked_on::Bool
    total_states::Int
    current_state::S
    const output_channel::Vector{SimulationResult{S,P}}

    function SimulationInstance(simulator::SIM, parameters::P) where {SIM,P}
        initial_state = new_initial_state!(simulator, parameters)
        S = typeof(initial_state)
        return new{SIM,S,P}(simulator, false, 1, initial_state, SimulationResult{S,P}[])
    end
end

function push_result!(instance::SimulationInstance, result::SimulationResult)
    instance.current_state = result.state
    push!(instance.output_channel, result)
    instance.total_states += 1

    return instance
end

@enum RunnerState state_stopped=0 state_running=1 state_stopping=2

function describe(state::RunnerState)
    return @match state::RunnerState begin
        state_stopped => "Simulation stopped"
        state_running => "Simulation running"
        state_stopping => "Simulation stopping"
    end
end

@enum RunnerCommand cmd_start=0 cmd_stop=1 cmd_new_initial_state=2

@enum RunnerEvent event_new_initial_state=0

mutable struct Runner{SIM,S,P,A}
    const outputs::Vector{Vector{SimulationResult{S,P}}}
    const tasks::Vector{Task}
    @atomic state::RunnerState
    @atomic parameters::P
    const commands::Vector{RunnerCommand}
    const instances::Vector{SimulationInstance{SIM,S,P}}
    const lk::ReentrantLock
    const analysis::Vector{A}
    const events::Vector{RunnerEvent}
end

struct NoAnalysis end

Base.push!(::NoAnalysis, ::Any) = NoAnalysis()

create_analysis(::Any) = NoAnalysis()

function new_initial_state! end

function Runner(simulators, parameters)
    instances = [SimulationInstance(simulator, parameters) for simulator in simulators]

    return Runner(
        [[SimulationResult(instance.current_state, parameters)] for instance in instances],
        Task[],
        state_stopped,
        parameters,
        RunnerCommand[],
        instances,
        ReentrantLock(),
        [create_analysis(instance.current_state) for instance in instances],
        RunnerEvent[],
    )
end

state(runner::Runner) = @atomic runner.state
number_of_instances(runner::Runner) = length(runner.instances)
number_of_states(runner::Runner) = minimum(length, runner.outputs)
events(runner::Runner) = runner.events


"""
    new_initial_state!(simulator, parameters)

Returns an initial simulation state.
"""
function new_initial_state! end

"""
    simulate!(simulator, parameters, state)

Advance the simulation one step by updating the given `state` and returning a new state. The `simulator` object can be mutated.
"""
function simulate! end

function new_initial_state!(runner::Runner)
    @assert state(runner) == state_stopped

    parameters = runner.parameters

    for (i, instance) in enumerate(runner.instances)
        initial_state = new_initial_state!(instance.simulator, parameters)

        empty!(instance.output_channel)
        instance.current_state = initial_state
        instance.total_states = 1

        output = runner.outputs[i]
        resize!(output, 1)
        output[1] = SimulationResult(initial_state, parameters)

        runner.analysis[i] = create_analysis(initial_state)
    end

    push!(runner.events, event_new_initial_state)

    return nothing
end

parameters(runner::Runner) = runner.parameters

function set_parameters!(runner::Runner, parameters)
    @atomic runner.parameters = parameters
    return parameters
end

function set_state!(runner::Runner, state::RunnerState)
    @atomic runner.state = state
    return state
end

function pick_instance(instances)
    min_index = 0
    min_value = typemax(Int)

    for (i, instance) in enumerate(instances)
        if !instance.is_being_worked_on && instance.total_states < min_value
            min_index = i
            min_value = instance.total_states
        end
    end

    if min_index == 0
        error("Every instance is already being worked on.")
    end

    return instances[min_index]
end

function run_simulator!(runner::Runner)
    (; lk, instances) = runner

    lock(lk)

    while @atomic(runner.state) !== state_stopping
        instance = pick_instance(instances)
        instance.is_being_worked_on = true
        parameters = runner.parameters

        unlock(lk)

        state = simulate!(instance.simulator, parameters, instance.current_state)
        result = SimulationResult(state, parameters)

        lock(lk)

        push_result!(instance, result)
        instance.is_being_worked_on = false
    end

    unlock(lk)

    return nothing
end

function fetch_output_channel!(runner::Runner)
    old_number_of_states = number_of_states(runner)

    lock(runner.lk)

    for (output, instance) in zip(runner.outputs, runner.instances)
        append!(output, instance.output_channel)
        empty!(instance.output_channel)
    end

    unlock(runner.lk)

    new_number_of_states = number_of_states(runner)

    for (analysis, output) in zip(runner.analysis, runner.outputs)
        for state_index in old_number_of_states+1:new_number_of_states
            push!(analysis, output[state_index].state)
        end
    end

    return nothing
end

function start!(runner::Runner)
    @assert state(runner) == state_stopped

    number_of_tasks = min(Threads.nthreads() - 1, number_of_instances(runner))

    if number_of_tasks == 0
        error("Please start Julia with more than one thread.")
    end

    set_state!(runner, state_running)

    resize!(runner.tasks, number_of_tasks)

    for i in 1:number_of_tasks
        runner.tasks[i] = Threads.@spawn run_simulator!($runner)
    end

    return nothing
end

function stop!(runner::Runner)
    set_state!(runner, state_stopping)

    for task in runner.tasks
        wait(task)
    end

    set_state!(runner, state_stopped)
    empty!(runner.tasks)

    fetch_output_channel!(runner)
    return nothing
end

function process_commands!(runner::Runner)
    commands = runner.commands
    finished_command = true

    while finished_command && !isempty(commands)
        finished_command = @match first(commands)::RunnerCommand begin
            cmd_start => @match state(runner)::RunnerState begin
                state_running => true
                state_stopping => false
                state_stopped => begin
                    start!(runner)
                    true
                end
            end
            cmd_stop => @match state(runner)::RunnerState begin
                state_running => begin
                    set_state!(runner, state_stopping)
                    true
                end
                state_stopping => true
                state_stopped => true
            end
            cmd_new_initial_state => @match state(runner)::RunnerState begin
                state_running => begin
                    set_state!(runner, state_stopping)
                    false
                end
                state_stopping => false
                state_stopped => begin
                    new_initial_state!(runner)
                    true
                end
            end
        end

        if finished_command
            popfirst!(commands)
        end
    end

    return nothing
end

function update!(runner::Runner)
    if !isempty(runner.tasks) && all(istaskdone, runner.tasks)
        for task in runner.tasks
            if istaskfailed(task)
                throw(TaskFailedException(task))
            end
        end

        set_state!(runner, state_stopped)
        empty!(runner.tasks)
        fetch_output_channel!(runner)
    end

    if state(runner) != state_stopped
        fetch_output_channel!(runner)
    end

    process_commands!(runner)

    return nothing
end

function request_start!(runner::Runner)
    push!(runner.commands, cmd_start)
    update!(runner)
    return nothing
end

function request_stop!(runner::Runner)
    push!(runner.commands, cmd_stop)
    update!(runner)
    return nothing
end

function request_new_initial_state!(runner::Runner)
    push!(runner.commands, cmd_new_initial_state)
    update!(runner)
    return nothing
end

function request_toggle!(runner::Runner)
    @match state(runner)::RunnerState begin
        state_running => request_stop!(runner)
        state_stopping => request_start!(runner)
        state_stopped => request_start!(runner)
    end

    return nothing
end
