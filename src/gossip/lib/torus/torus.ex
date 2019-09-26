defmodule Torus do

  def main(n3) do
    n=ceil(:math.pow(n3, :math.pow(3, -1)))
    chk_cube_rt(n3, n)

    #start agent
    {:ok, agnt_pid}=Agent.start_link(fn-> %{} end)

    #start dispenser
    {:ok, disp_pid}=Torus.Dispenser.start_link

    #Fork workers
    for _x<-0..n3-1, do: Torus.Worker.start_link(n, agnt_pid, disp_pid)
  end

  def chk_cube_rt(n3, n) when rem(n3, n)==1, do: System.halt(1)
  def chk_cube_rt(n3, n) when rem(n3, n)==0, do: :ok

end
