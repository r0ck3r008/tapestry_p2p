defmodule Tapestry.Init do

  def main(n, failPercent) do
    #start dispenser
    {:ok, disp_pid}=Tapestry.Dispenser.start_link

    #start nodes
    nodes=for _x<-0..n-1, do: Tapestry.Node.start_link
    tasks=for {_, pid}<-nodes, do: Task.async(fn-> task_fn(pid, n, disp_pid, 0) end)
    :timer.sleep(1000)
    dolr_publish(n, failPercent, disp_pid, Enum.map(nodes, fn({:ok, pid})-> pid end))
    #makes main never exit
    for task<-tasks, do: Task.await(task, :infinity)
  end

  def task_fn(pid, n, disp_pid, 0) do
    Tapestry.Node.update_route(pid, n, disp_pid)
    task_fn(pid, n, disp_pid, 1)
  end
  def task_fn(pid, n, disp_pid, count) do
    :timer.sleep(1000)
    task_fn(pid, n, disp_pid, count)
  end

  def dolr_publish(n, failPercent, disp_pid, nodes) do
    #wait for all to fetch nbor table
    nbors_done?(disp_pid, Tapestry.Dispenser.fetch_assigned(disp_pid))

    #kill nodes
    IO.puts "Killing #{failPercent}% nodes"
    n_kill=(n*(div(failPercent, 100)))
    for x<-0..n_kill-1, do: GenServer.stop(Enum.at(nodes, x), :normal)
    nodes_killed=for x<-0..n_kill-1, do: Enum.at(nodes, x)
    nodes=nodes--nodes_killed

    len=length(nodes)
    publisher=Enum.at(nodes, :rand.uniform(len)-1)
    rqstr_1=Enum.at(nodes, :rand.uniform(len)-1)
    rqstr_2=Enum.at(nodes, :rand.uniform(len)-1)

    #publish
    Tapestry.Dolr.publish("HELLO", publisher)
    :timer.sleep(3000)

    #find obj
    IO.puts "Finding now"
    Tapestry.Dolr.route_to_obj("HELLO", rqstr_2)
    :timer.sleep(2000)

    #unpublish
    IO.puts "Unpublishing now"
    Tapestry.Dolr.unpublish("HELLO", publisher)
    :timer.sleep(2000)

    #find object
    IO.puts "Trying to find after unpublishing!"
    Tapestry.Dolr.route_to_obj("HELLO", rqstr_1)
    :timer.sleep(3000)

    #kill all
    for node<-nodes, do: GenServer.stop(node, :normal)
    System.halt(0)
  end

  def nbors_done?(_disp_pid, 0), do: :ok
  def nbors_done?(disp_pid, _assigned), do: nbors_done?(disp_pid, Tapestry.Dispenser.fetch_assigned(disp_pid))

end
