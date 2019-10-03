defmodule Honeycomb_rand do

  use GenServer

  def start_link(n2, algo) do
    t=get_t(n2)

    #start agent
    {:ok, agnt_pid}=Agent.start_link(fn-> %{} end)

    #start dispenser
    {:ok, disp_pid}=Honeycomb_rand.Dispenser.start_link

    #start timer
    {:ok, timer_pid}=Timer.start_link

    #start genserver
    {:ok, main_pid}=GenServer.start(__MODULE__, {n2, timer_pid})

    #make forbidden x and y
    frbdn=mk_frbdn(t-1)

    #start workers
    workers=for x<-0..n2-1, do: Honeycomb_rand.Worker.start_link(x)
    workers=for {_, wrkr}<-workers, do: wrkr
    tasks=for wrkr<-workers, do: Task.async(fn-> Honeycomb_rand.Worker.update_nbors(wrkr, t-1, disp_pid, agnt_pid, main_pid, frbdn) end)
    for task<-tasks, do: Task.await(task, :infinity)

    start_rumor(t-1, algo, agnt_pid, timer_pid, disp_pid, frbdn)
  end

  def get_t(n2) do
    chk_sqrt(div(n2, 6), ceil(:math.sqrt(div(n2, 6))))
  end

  def chk_sqrt(n2_6, n) when rem(n2_6, n)==0, do: n
  def chk_sqrt(n2_6, n) when rem(n2_6, n)==1 do
    IO.puts "Error number must be of the form 6t^2"
    System.halt(1)
  end

  def mk_frbdn(t) do
    x_1=for x<-0..(t-1), do: x
    x_2=for x<-(t+2)..(2*t+1), do: x
    y_1=for y<-0..(t-1), do: y
    y_2=for y<-(3*t+3)..(4*t+2), do: y
    {
      x_1++x_2,
      y_1++y_2
    }
  end

  def start_rumor(t, algo, agnt_pid, timer_pid, disp_pid, frbdn) do
    #remove deadlocks
    num=6*(ceil(:math.pow(t+1, 2)))
    Honeycomb_rand.Worker.remove_deadlocks(disp_pid, num, num-Honeycomb_rand.Dispenser.get_done_num(disp_pid))

    #start timer
    Timer.start_timer(timer_pid)

    pid=Agent.get(agnt_pid, &Map.get(&1, Honeycomb_rand.Worker.gen_rand_co_ords(t, frbdn, nil)))
    wrkr_mod=Honeycomb_rand.Worker
    algo.send_rum(
      wrkr_mod,
      pid
    )
  end

  def get_state(of) do
    GenServer.call(of, :get_state)
  end

  def converged(self_pid) do
    {t, n_converged, timer_pid}=get_state(self_pid)
    dlta=(6*(ceil(:math.pow(t, 2))))-n_converged

    if dlta==0 do
      #stop timer
      IO.puts "All done!"
      Timer.end_timer(timer_pid)
      System.halt(0)
    else
      GenServer.cast(self_pid, :inc_converged)
    end
  end

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
    IO.puts "#{((n_converged+1)/num)*100}% converged"
    {:noreply, {num, n_converged+1, timer_pid}}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

end
