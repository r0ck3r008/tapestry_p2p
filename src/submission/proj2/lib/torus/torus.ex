defmodule Torus do

  use GenServer

  #external API
  def start_link(n3, algo) do
    n=ceil(:math.pow(n3, :math.pow(3, -1)))
    chk_cube_rt(n3, n)

    #start agent
    {:ok, agnt_pid}=Agent.start_link(fn-> %{} end)

    #start dispenser
    {:ok, disp_pid}=Torus.Dispenser.start_link

    #start timer
    {:ok, timer_pid}=Timer.start_link

    #start server
    {:ok, main_pid}=GenServer.start_link(__MODULE__, {n3, timer_pid})

    #Fork workers
    workers=for x<-0..n3-1, do: Torus.Worker.start_link(x)
    workers=for {_, wrkr}<-workers, do: wrkr
    tasks=for wrkr<-workers, do: Task.async(fn-> Torus.Worker.update_state(wrkr, n, agnt_pid, disp_pid, main_pid) end)

    for task<-tasks, do: Task.await(task, :infinity)

    #start rumor
    start_rumor(n, algo, agnt_pid, timer_pid, disp_pid)
  end

  def chk_cube_rt(n3, n) when rem(n3, n)==1 do
    IO.puts "Entered number must be a perfet cube! Exiting..."
    System.halt(0)
  end
  def chk_cube_rt(n3, n) when rem(n3, n)==0, do: :ok

  def start_rumor(num, algo, agnt_pid, timer_pid, disp_pid) do
    #deadlock protection
    n3=ceil(:math.pow(num, 3))
    Torus.Worker.remove_deadlocks(disp_pid, n3, n3-Torus.Dispenser.get_done_count(disp_pid))
    #start timer
    Timer.start_timer(timer_pid)

    #send first rumor
    wrkr_mod=Torus.Worker
    algo.send_rum(
      wrkr_mod,
      Agent.get(agnt_pid, &Map.get(&1,{
        Salty.Random.uniform(num),
        Salty.Random.uniform(num),
        Salty.Random.uniform(num)
      }
      ))
    )
  end

  def get_state(self_pid) do
    GenServer.call(self_pid, :get_state)
  end

  def converged(self_pid) do
    {n3, n_converged, timer_pid}=get_state(self_pid)
    delta=n3-n_converged

    if delta==1 do
      IO.puts "All Done!"
      Timer.end_timer(timer_pid)
      System.halt(0)
    else
      GenServer.cast(self_pid, :inc_converged)
    end
  end

  #callbacks
  @impl true
  def init(attrs) do
    Process.flag(:trap_exit, true)
    {:ok, {elem(attrs, 0), 0, elem(attrs, 1)}}
  end

  @impl true
  def terminate(_, _) do
    IO.puts "Terminating as not converged!"
    System.halt(0)
  end

  @impl true
  def handle_cast(:inc_converged, {num, n_converged, timer_pid}) do
    IO.puts "#{((n_converged+1)/num)*100}% done!"
    {:noreply, {num, n_converged+1, timer_pid}}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

end