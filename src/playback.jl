struct PlaybackPosition
    number_of_states::Int
    state_index::Int
    cursor_offset::Float64

    function PlaybackPosition(number_of_states::Int, state_index::Int, cursor_offset::Float64)
        @assert number_of_states >= 1 && 1 <= state_index <= number_of_states && 0 <= cursor_offset <= 1
        return new(number_of_states, state_index, cursor_offset)
    end
end

function cursor_position(position::PlaybackPosition)
    return min((position.state_index + position.cursor_offset - 1) / position.number_of_states, 1)
end

function move_to(position::PlaybackPosition, to::Float64)
    number_of_states = position.number_of_states
    cursor_position = clamp(to, 0, 1)

    x = cursor_position * number_of_states + 1

    state_index = min(floor(Int, x), number_of_states)
    cursor_offset = x - state_index

    return PlaybackPosition(number_of_states, state_index, cursor_offset)
end

function next(position::PlaybackPosition)
    number_of_states = position.number_of_states
    state_index = position.state_index

    if state_index < number_of_states
        return PlaybackPosition(number_of_states, state_index + 1, 0.0)
    end

    return position
end

function previous(position::PlaybackPosition)
    number_of_states = position.number_of_states
    state_index = position.state_index

    if state_index > 1
        return PlaybackPosition(number_of_states, state_index - 1, 0.0)
    end

    return position
end

@enum PlaybackState playback_stopped=0 playback_running=1 playback_cursor_being_moved=2 playback_live=3

function describe(state::PlaybackState)
    return @match state::PlaybackState begin
        playback_stopped => "Playback stopped"
        playback_running => "Playing recorded simulation"
        playback_cursor_being_moved => "Cursor is being moved"
        playback_live => "Live simulation"
    end
end

@enum JumpPressState jump_none=0 jump_forward=1 jump_backward=2

mutable struct Playback
    state::PlaybackState
    last_cursor_update_time::Float64
    speed::Float64
    jump_press_time::Float64
    jump_press_state::JumpPressState
    position::PlaybackPosition
end

Playback() = Playback(playback_live, 0.0, 0.0, 0.0, jump_none, PlaybackPosition(1, 1, 1.0))

state(playback::Playback) = playback.state
index(playback::Playback) = playback.position.state_index

is_stopped(playback::Playback)            = playback.state == playback_stopped
is_running(playback::Playback)            = playback.state == playback_running
is_cursor_being_moved(playback::Playback) = playback.state == playback_cursor_being_moved
is_live(playback::Playback)               = playback.state == playback_live

is_jump_pressed(playback::Playback) = playback.jump_press_state != jump_none

function reset!(playback::Playback)
    playback.state = playback_live
    playback.position = PlaybackPosition(1, 1, 1.0)
    playback.jump_press_state = jump_none
    return nothing
end

function set_to_stopped!(playback::Playback)
    playback.state = playback_stopped
    return nothing
end

function set_to_running!(playback::Playback)
    playback.last_cursor_update_time = time()
    playback.speed = 0.5
    playback.state = playback_running
    return nothing
end

function set_to_cursor_being_moved!(playback::Playback)
    playback.state = playback_cursor_being_moved
    return nothing
end

function set_to_live!(playback::Playback)
    playback.position = move_to(playback.position, 1.0)
    playback.state = playback_live
    return nothing
end

function jump_forward!(playback::Playback)
    set_to_stopped!(playback)
    playback.position = next(playback.position)
    playback.jump_press_state = jump_forward
    playback.jump_press_time = time()
    return nothing
end

function jump_backward!(playback::Playback)
    set_to_stopped!(playback)
    playback.position = previous(playback.position)
    playback.jump_press_state = jump_backward
    playback.jump_press_time = time()
    return nothing
end

function release_jump_key!(playback::Playback)
    playback.jump_press_state = jump_none

    if is_running(playback)
        set_to_stopped!(playback)
    end

    return nothing
end

function toggle_playback!(playback::Playback, is_simulator_running::Bool)
    if is_stopped(playback)
        if is_simulator_running
            set_to_live!(playback)
        else
            set_to_running!(playback)
        end
    elseif is_running(playback) || is_live(playback)
        set_to_stopped!(playback)
    end

    return nothing
end

# FIXME: if simulation is running and user holds the jump key, then the playback is broken.
function update!(playback::Playback, number_of_states::Int)
    position = playback.position

    if position.number_of_states != number_of_states
        playback.position = PlaybackPosition(number_of_states, position.state_index, position.cursor_offset)

        if is_running(playback)
            set_to_stopped!(playback)
        elseif is_live(playback)
            playback.position = move_to(playback.position, 1.0)
        end
    end

    if !is_running(playback) && is_jump_pressed(playback) && time() - playback.jump_press_time >= 0.2
        set_to_running!(playback)
        playback.speed = playback.jump_press_state == jump_forward ? 0.5 : -0.5
        playback.jump_press_state = jump_none
    end

    if is_running(playback)
        cursor_pos = cursor_position(position)

        current_time = time()
        cursor_pos += playback.speed * (current_time - playback.last_cursor_update_time)

        if cursor_pos <= 1
            playback.last_cursor_update_time = current_time
            playback.position = move_to(position, cursor_pos)
        else
            playback.jump_press_state = jump_none
            set_to_live!(playback)
        end
    end

    return nothing
end
