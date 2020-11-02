defmodule PolyglotWatcher.Executor do
  alias PolyglotWatcher.Languages.Elixir, as: ElixirLang

  def run_actions({%{run: actions, next: next}, server_state}) do
    {actions, server_state}
    |> run_series_of_actions()
    |> run_actions_chain(next)
  end

  def run_actions({actions, server_state}) when is_list(actions) do
    {_last_action_result, server_state} = run_series_of_actions({actions, server_state})
    server_state
  end

  def run_actions({_, server_state}), do: server_state

  defp run_actions_chain({_last_action_result, server_state}, nil), do: server_state

  defp run_actions_chain({prev_action_result, server_state}, next) do
    actions = next[prev_action_result]
    {actions_result, server_state} = run_series_of_actions({actions.run, server_state})
    run_actions_chain({actions_result, server_state}, actions[next])
  end

  defp run_series_of_actions({actions, server_state}) do
    Enum.reduce(actions, {nil, server_state}, fn action, {_prev_result, server_state} ->
      run_action(action, server_state)
    end)
  end

  defp run_action({:run_sys_cmd, cmd, args}, server_state) do
    {System.cmd(cmd, args, into: IO.stream(:stdio, :line)), server_state}
  end

  defp run_action({:mix_test, path}, server_state) do
    {output, _} = System.cmd("mix", ["test", path, "--color"])
    {IO.puts(output), ElixirLang.add_mix_test_history(server_state, output)}
  end

  defp run_action({:run_elixir_fn, fun}, server_state), do: {fun.(), server_state}
end