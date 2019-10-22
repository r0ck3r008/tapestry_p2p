defmodule Tapestry.Node do

  use GenServer

  def start_link do
    {:ok, agnt_pid}=Agent.start_link(fn-> [] end)
    GenServer.start_link(__MODULE__, agnt_pid)
  end

  def update_route(of, num, disp_pid) do
    hash=Tapestry.Node.Helper.hash_it(inspect of)
    GenServer.cast(of, {:assign_hash, hash, disp_pid})

    #remove deadlocks
    Tapestry.Node.Helper.remove_deadlocks(num, disp_pid, num-Tapestry.Dispenser.fetch_assigned(disp_pid))

    nbor_t=Task.async(fn-> Tapestry.Dispenser.Hash_helper.get_nbors(disp_pid, hash) end)
    GenServer.cast(of,
      {
        :update_nbors,
        Task.await(nbor_t, :infinity)
      })
  end

  #callbacks
  @impl true
  def init(agnt_pid) do
    {:ok, agnt_pid}
  end

  @impl true
  def handle_cast({:assign_hash, hash, disp_pid}, agnt_pid) do
    {:noreply,
      {
        Tapestry.Dispenser.assign_hash(disp_pid, self(), hash),
        agnt_pid
      }
    }
  end

  @impl true
  def handle_cast({:update_nbors, nbors}, {hash, agnt_pid}) do
    #remove self
    nbors=Enum.uniq([{hash, self()}]++nbors)
    {:noreply, {nbors, agnt_pid}}
  end

  @impl true
  def handle_info({:publish, msg_hash, srvr_pid}, {nbors, agnt_pid}) do
    IO.puts "[#{elem(hd(nbors), 0)}] Publishing #{msg_hash}!"
    Tapestry.Node.Helper.publish(nbors, agnt_pid, {msg_hash, srvr_pid})
    {:noreply, {nbors, agnt_pid}}
  end

  @impl true
  def terminate(_, {nbors, _}) do
    IO.puts "Terminating Node #{elem(hd(nbors), 0)}"
  end

end
