defmodule Project2 do
  @moduledoc """
  Documentation for Project2.
  """
  use GenServer

    # API
  
    @doc """
    Code for starting the GenServer that tracks the count of dead nodes.
    
    * Starts the GenServer.
    * Registers the server globally.
    * Checks for convergence based on number of dead nodes.
    """
  @name :monitor_server

  def start_link(state) do
    GenServer.start_link(__MODULE__, state)
  end

  @doc """
  handle_cast method for GenServer.
  Calculates percentage of dead nodes and checks for convergence.
  """   
  def handle_cast({:process_died, pid}, state) do
    [time_start , algorithm | state_rem] = state
    dead_process = List.first(state_rem)  # Number of dead processes
    numNodes = List.last(state_rem)
    perc_nodes_dead = ((dead_process + 1) * 100)
    perc_nodes_dead = perc_nodes_dead / numNodes  # Percent of dead processes

    # Converge when 75 percent of the actors have terminated
    if perc_nodes_dead < 75 do
      {:noreply, [time_start, algorithm, dead_process + 1, numNodes]}
    else
      time_now = System.system_time(:millisecond)
      total_time = time_now - time_start
      IO.puts "Time:" <> to_string(total_time) <> "ms"
      {:stop, :shutdown, []}
    end
  end

  def main(args) do
    [numNodes, topology, algorithm] = args
    # Round the number of nodes to the lowest perfect square
    numNodes = round(:math.pow(round(Float.floor(:math.sqrt(String.to_integer(numNodes)))), 2))

    # Start the monitor server
    {:ok, monitor_pid} = Project2.start_link([System.system_time(:millisecond), algorithm, 0, numNodes])
    :global.register_name(@name, monitor_pid)
    list_of_nodes = []
    # Create the list of actors
    list_of_nodes = for nodeNum <- 1..(numNodes) do
      {:ok, pid} = case algorithm do
        "gossip" -> Project2.Server.start_link(0)
        "push-sum" -> 
          s = nodeNum - 1
          w = 1
          Project2.Server.start_link([0, s, w])
      end      
      pid
    end
    
    # Initiate the Gossip/Push Sum algorithm
    case algorithm do
      "gossip" -> Project2.Server.send_rumours(List.first(list_of_nodes), [], list_of_nodes, topology)
      "push-sum" -> Project2.Server.send_rumours(List.first(list_of_nodes), [0, 0], list_of_nodes, topology)
    end
    :timer.sleep(:infinity)
  end
end