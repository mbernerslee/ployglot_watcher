defmodule PolyglotWatcher.Elm.LanguageTest do
  use ExUnit.Case, async: true
  alias PolyglotWatcher.ServerStateBuilder
  alias PolyglotWatcher.Elm.Language, as: Elm
  alias PolyglotWatcher.Elm.Actions

  describe "determine_actions/2" do
    test "given a Main.elm file backed by an elm.json" do
      file = %{extension: ".elm", file_path: "test/elm_examples/simplest_project/src/Main.elm"}
      server_state = ServerStateBuilder.build()

      assert {actions, ^server_state} = Elm.determine_actions(file, server_state)

      assert %{
               run: [
                 {:cd, "test/elm_examples/simplest_project"},
                 {:puts, "Running elm make test/elm_examples/simplest_project/src/Main.elm"},
                 {:module_action, Actions, {:make, "src/Main.elm"}}
               ],
               next: %{fallback: %{run: [{:run_sys_cmd, "tput", ["reset"]}, :reset_dir]}}
             } = actions
    end

    test "returns as error if no elm main or elm json is found" do
      file = %{extension: ".elm", file_path: "test/elm_examples/NoMainJankFile.elm"}
      server_state = ServerStateBuilder.build()

      assert {actions, _server_state} = Elm.determine_actions(file, server_state)

      assert [
               {:puts,
                [
                  {:red,
                   "I could not find a corresponding elm.json and / or Main.elm file(s) for the file you saved:"}
                ]},
               {:puts, [{:red, "test/elm_examples/NoMainJankFile.elm"}]}
             ] = actions
    end

    test "given an elm file backjed by Main.elm & elm.json" do
      file = %{
        extension: ".elm",
        file_path: "test/elm_examples/project_with_two_files/src/OtherFile.elm"
      }

      server_state = ServerStateBuilder.build()

      assert {actions, _server_state} = Elm.determine_actions(file, server_state)

      assert %{
               run: [
                 {:cd, "test/elm_examples/project_with_two_files"},
                 _,
                 {:module_action, Actions, {:make, "src/Main.elm"}}
               ],
               next: _
             } = actions
    end

    test "given deeply nested elm file backjed by Main.elm & elm.json" do
      file = %{
        extension: ".elm",
        file_path: "test/elm_examples/nested_directory_project/src/one/two/three/four/File.elm"
      }

      server_state = ServerStateBuilder.build()

      assert {actions, _server_state} = Elm.determine_actions(file, server_state)

      assert %{
               run: [
                 {:cd, "test/elm_examples/nested_directory_project"},
                 _,
                 {:module_action, Actions, {:make, "src/Main.elm"}}
               ],
               next: _
             } = actions
    end

    # TODO add a test for when elm json and or main are not found
  end
end
