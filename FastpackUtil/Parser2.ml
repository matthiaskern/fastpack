module Loc = FlowParser.Loc
let parse_options = Some FlowParser.Parser_env.({
    esproposal_optional_chaining = false;
    esproposal_class_instance_fields = true;
    esproposal_class_static_fields = true;
    esproposal_decorators = true;
    esproposal_export_star_as = true;
    types = true;
    use_strict = false;
  })

let get_details ~source ~errors =
  let lineno_width = 4 in
  let separator = "| " in
  let lines =
    String.lines source
    |> List.mapi (fun i line ->
        let lineno =
          String.pad ~side:`Left ~c:' ' lineno_width (string_of_int (i + 1))
        in
        lineno ^ separator ^ line
      )
    |> Array.of_list
  in
  errors
  |> List.map (fun ((loc : Loc.t), err) ->
      let line = lines.(loc.start.line - 1) in
      let pointer =
        String.pad ~side:`Left ~c:' '
          (lineno_width + String.length separator + loc.start.column + 1)
          "^"
      in
      line ^ "\n" ^ pointer ^ " " ^ FlowParser.Parse_error.PP.error err
    )
  |> List.map (fun line -> [([], line)])

let get_suggestion location_str =
  let ext = location_str |> String.split_on_char '.' |> List.rev in
  match ext with
  | [] -> None
  | ext :: _ ->
    match ext with
    | "css" ->
      Some PrettyPrint.(empty |> string (
        "Looks like you are trying to parse the CSS file. "
        ^ "Try to preprocess them like this:\n"
        ^ "  --preprocess='\\.css$:style-loader!css-loader'"
      ))
    | _ ->
      None

let get_error ~source ~errors =
  let open PrettyPrint in
  let lineno_width = 4 in
  let separator = "| " in
  let source_lines =
    String.lines source
    |> List.mapi (fun i line ->
        let lineno =
          String.pad ~side:`Left ~c:' ' lineno_width (string_of_int (i + 1))
        in
        lineno ^ separator ^ line
      )
    |> Array.of_list
  in
  errors
  |> List.fold_left (fun acc ((loc : Loc.t), error) ->
      let pointer =
        String.pad ~side:`Left ~c:' '
          (lineno_width + String.length separator + loc.start.column + 1)
          "^"
      in
      acc
      |> string (source_lines.(loc.start.line - 1))
      |> nl
      |> red
      |> string (pointer ^ " " ^ FlowParser.Parse_error.PP.error error)
      |> normal
      |> nl
    )
    (empty |> bold |> red |> string "Parse Errors:" |> normal |> nl)



let parse ~location_str source =
  Run.(withContext ("Parsing " ^ location_str) (
    try
      return (FlowParser.Parser_flow.program source ~parse_options)
    with
    | FlowParser.Parse_error.Error errors ->
      match get_suggestion location_str with
      | Some suggestion ->
        with_suggestion suggestion (error_str "Parse Error")
      | None ->
        get_error ~source ~errors |> error
  ))
