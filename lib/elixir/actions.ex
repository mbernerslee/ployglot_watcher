defmodule PolyglotWatcher.Elixir.Actions do
  alias PolyglotWatcher.Puts
  alias PolyglotWatcher.Elixir.Language

  # TODO collapse this module into Elixir.Language?

  @success_exit_code 0

  def mix_test do
    {:module_action, __MODULE__, :mix_test}
  end

  def mix_test_quietly do
    {:module_action, __MODULE__, :mix_test_quietly}
  end

  def mix_test(test_path) do
    {:module_action, __MODULE__, {:mix_test, test_path}}
  end

  def mix_test_head_single do
    {:module_action, __MODULE__, :mix_test_head_single}
  end

  def mix_test_head_file_quietly do
    {:module_action, __MODULE__, :mix_test_head_file_quietly}
  end

  def mix_test_failed_one do
    {:module_action, __MODULE__, :mix_test_failed_one}
  end

  @chars ["|", "/", "-", "\\"]
  @char_count length(@chars)

  defp spinner, do: spawn(fn -> spin() end)

  defp spin, do: spin(0)

  defp spin(char_index) do
    char = Enum.at(@chars, rem(char_index, @char_count))
    Puts.appendfully_overwrite("   #{char}", :green)
    :timer.sleep(50)
    spin(char_index + 1)
  end

  defp put_summary({:ok, summary}, @success_exit_code) do
    Puts.appendfully_overwrite("✓", :green)
    Puts.append("   #{summary}", :green)
    Puts.on_new_line("", :magenta)
  end

  defp put_summary({:ok, summary}, _) do
    Puts.appendfully_overwrite("\u274C", :red)
    Puts.append("   #{summary}", :red)
    Puts.on_new_line("", :magenta)
  end

  defp put_summary({:error, error}, _) do
    IO.puts(error)
  end

  # TODO add spinner tests somehow?
  # TODO abstract away the spinner stuff into a function that recieves a do block "do while spinning" or "spin while"
  def run_action(:mix_test_quietly, server_state) do
    spinner_pid = spinner()
    {mix_test_output, exit_code} = System.cmd("mix", ["test", "--color"])
    Process.exit(spinner_pid, :kill)

    mix_test_output
    |> Language.mix_test_summary()
    |> put_summary(exit_code)

    # TODO add a test that would fail if this was add instead of reset!
    {exit_code, Language.reset_mix_test_history(server_state, mix_test_output)}
  end

  def run_action({:mix_test, path}, server_state) do
    {mix_test_output, exit_code} = System.cmd("mix", ["test", path, "--color"])
    IO.puts(mix_test_output)
    {exit_code, Language.add_mix_test_history(server_state, mix_test_output)}
  end

  def run_action(:mix_test, server_state) do
    {mix_test_output, exit_code} = System.cmd("mix", ["test", "--color"])
    IO.puts(mix_test_output)
    {exit_code, Language.reset_mix_test_history(server_state, mix_test_output)}
  end

  def run_action(:mix_test_head_single, server_state) do
    case server_state.elixir.failures do
      [] ->
        # TODO deal with this better
        Puts.on_new_line(
          "i expected there to be at least one failing test in my memory, but there were none",
          :red
        )

        {1, Language.set_mode(server_state, {:fix_all, :mix_test})}

      [failure | _rest] ->
        run_action({:mix_test, failure}, server_state)
    end
  end

  # TODO no test goes through this codepath. add one
  def run_action(:mix_test_head_file_quietly, server_state) do
    case server_state.elixir.failures do
      [] ->
        Puts.on_new_line(
          "i expected there to be at least one failing test in my memory, but there were none",
          :red
        )

        {1, Language.set_mode(server_state, {:fix_all, :mix_test})}

      [failure | _rest] ->
        file = trim_line_number(failure)
        spinner_pid = spinner()
        {mix_test_output, exit_code} = System.cmd("mix", ["test", file, "--color"])
        Process.exit(spinner_pid, :kill)

        mix_test_output
        |> Language.mix_test_summary()
        |> put_summary(exit_code)

        server_state =
          Language.update_mix_test_history_for_file(server_state, file, mix_test_output)

        {exit_code, server_state}
    end
  end

  def run_action(:mix_test_failed_one, server_state) do
    spinner_pid = spinner()

    {mix_test_output, exit_code} =
      System.cmd("mix", ["test", "--color", "--failed", "--max-failures", "1"])

    Process.exit(spinner_pid, :kill)

    mix_test_output
    |> Language.mix_test_summary()
    |> put_summary(exit_code)

    {exit_code, Language.put_failures_first(server_state, mix_test_output)}
  end

  defp trim_line_number(test_failure_with_line_number) do
    test_failure_with_line_number |> String.split(":") |> hd()
  end
end
