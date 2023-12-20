function compile_shader(shader_path, shader_type)
    shader = glCreateShader(shader_type)

    shader_src = read(shader_path)
    GC.@preserve shader_src glShaderSource(shader, 1, Ref{Ptr{GLchar}}(pointer(shader_src)), Ref{GLint}(length(shader_src)))

    glCompileShader(shader)

    status = Ref{GLint}()
    glGetShaderiv(shader, GL_COMPILE_STATUS, status)

    if status[] == GL_FALSE
        info_log_length = Ref{GLint}()
        glGetShaderiv(shader, GL_INFO_LOG_LENGTH, info_log_length)

        info_log = Vector{GLchar}(undef, info_log_length[])
        glGetShaderInfoLog(shader, info_log_length[], info_log_length, info_log)

        error(GC.@preserve info_log unsafe_string(pointer(info_log), info_log_length[]))
    end

    return shader
end

function link_program(vertex_shader, fragment_shader)
    program = glCreateProgram()
    glAttachShader(program, vertex_shader)
    glAttachShader(program, fragment_shader)
    glLinkProgram(program)

    status = Ref{GLint}()
    glGetProgramiv(program, GL_LINK_STATUS, status)

    if status[] == GL_FALSE
        info_log_length = Ref{GLint}()
        glGetProgramiv(program, GL_INFO_LOG_LENGTH, info_log_length)

        info_log = Vector{GLchar}(undef, info_log_length[])
        glGetProgramInfoLog(program, info_log_length[], info_log_length, info_log)

        error(GC.@preserve info_log unsafe_string(pointer(info_log), info_log_length[]))
    end

    return program
end

function setup_shader_program(vertex_shader_path, fragment_shader_path)
    vertex_shader = compile_shader(vertex_shader_path, GL_VERTEX_SHADER)
    fragment_shader = compile_shader(fragment_shader_path, GL_FRAGMENT_SHADER)
    program = link_program(vertex_shader, fragment_shader)

    glDeleteShader(vertex_shader)
    glDeleteShader(fragment_shader)

    return program
end
