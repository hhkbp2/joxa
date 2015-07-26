#!/usr/bin/env escript
%%! -pa ebin

main(["compile_ast_to_beam", ASTFile, OutputDir]) ->
    {ok, [AST]} = file:consult(ASTFile),
    {c_module, _,
     {c_literal, _, ModuleName}, _, _, _} = AST,
    update_code_path(),
    case compile:forms(AST, [binary, from_core, return_errors, debug_info]) of
        {ok, _, Result} ->
            OutputFile = filename:join(OutputDir,
                                       erlang:atom_to_list(ModuleName) ++ ".beam"),
            ok = file:write_file(OutputFile, Result);
        Error ->
            erlang:throw(Error)
    end;
main(["compile_jxa_to_beam", InputFile, OutputDir]) ->
    update_code_path(),
    'joxa-compiler':'do-compile'(InputFile, [{outdir, OutputDir}]);
main(["compile_jxa_to_ast", InputFile, OutputDir, OutputFile]) ->
    update_code_path(),
    'joxa-compiler':'do-compile'(InputFile, [to_ast, {outdir, OutputDir}]),
    file:write_file(OutputFile, <<".">>, [append]).

update_code_path() ->
    %% add deps/*/ebin to code path
    code:add_pathsz(filelib:wildcard(filename:join(["deps", "*", "ebin"]))).

