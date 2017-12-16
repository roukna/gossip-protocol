defmodule Project2.Server do
  @moduledoc """
  Documentation for Project2.Server module.
  """
  use GenServer
  use Application
  
  # API

  @doc """
  Code for starting the GenServer on each actor that participates in the Gossip/Push Sum process.
  
  * Starts the GenServer.
  * For gossip, receives rumour and transmits rumour to any random node.
  * For push sum, receives [s,w] value and transmits the new [s,w] value.
  """
  @name :monitor_server
  
  def start_link(state) do
    GenServer.start_link(__MODULE__, state)
  end

  @doc """
  Calls the handle_cast method of the genserver to send the rumour/push sum value to a random neighbour.
  For Gossip, this method calls itself recursively to spread the gossip to any random neighbour periodically.
  """  
  def send_rumours(pid, rumour, list_of_nodes, topology) do
    n_pid = get_random_neighbour(pid, list_of_nodes, topology)
    GenServer.cast(n_pid, {:send_rumour, rumour, list_of_nodes, topology})
    # If algorithm is Gossip, rumour is blank.
    if length(rumour) == 0 do
      send_rumours(pid, rumour, list_of_nodes, topology)
    end
  end
  
  @doc """
  Returns pid of a random neighbour based on the topology used.
  """
  def get_random_neighbour(pid, list_of_nodes, topology) do
    case topology do
      "full" ->
        n_pid = Enum.random(List.delete(list_of_nodes, pid))
      "line" -> 
        if List.first(list_of_nodes) == pid do
          n_pid = Enum.at(list_of_nodes, 1)
        else 
          if List.last(list_of_nodes) == pid do
            n_pid = Enum.at(list_of_nodes, length(list_of_nodes) - 1)
          else
            # Returns either the left or right neighbour
            random_step = Enum.random([1,-1])
            pid_index = Enum.find_index(list_of_nodes, fn(x) -> x==pid end)
            neighbour_index = pid_index + random_step
            n_pid = Enum.at(list_of_nodes, neighbour_index)
          end
        end
      "2D" ->
        numNodes = length(list_of_nodes)
        n = round(Float.floor(:math.sqrt(numNodes)))
        pid_index = Enum.find_index(list_of_nodes, fn(x) -> x==pid end)
        rowNum = round(Float.floor(pid_index/n))
        colNum = rem(pid_index,n)
        neighbours = []

        if (rowNum == 0) || (rowNum == n-1) do        
          # The corner elements
          if (colNum == 0) || (colNum == n-1) do
            # Each corner elements
            x = n - 1
            neighbours = case {rowNum, colNum} do
              {0, 0} -> [{0,1}, {1,0}]
              {0, x} -> [{0, x-1}, {1, x}]
              {x, 0} -> [{x-1, 0}, {x, 1}]
              {x, x} -> [{x, x-1}, {x-1, x}]
            end
          else
            # Row edge elements other than corner elements
            x = n - 1
            neighbours = case rowNum do
              0 -> [{0,colNum-1}, {0, colNum+1}, {1, colNum}]
              x -> [{x,colNum-1}, {x, colNum+1}, {x-1, colNum}]
            end
          end
        else
          if (colNum == 0 ) || (colNum == n-1) do
            # Column edge elements other than corner elements
            x = n - 1
            neighbours = case colNum do
              0 -> [{rowNum-1,0}, {rowNum+1, 0}, {rowNum, 1}]
              x -> [{rowNum-1,x}, {rowNum+1, x}, {rowNum, x-1}]
            end
          else
            # Inside elements
            x = n - 1
            neighbours = [{rowNum-1,colNum}, {rowNum+1, colNum}, {rowNum, colNum-1}, {rowNum, colNum+1}]
          end
        end
        rand_neighbour = Enum.random(neighbours)
        randRow = elem(rand_neighbour, 0)
        randCol = elem(rand_neighbour, 1)
        neighbour_index = n * randRow + randCol
        n_pid = Enum.at(list_of_nodes, neighbour_index)
      "imp2D" ->
        numNodes = length(list_of_nodes)
        n = round(Float.floor(:math.sqrt(numNodes)))
        pid_index = Enum.find_index(list_of_nodes, fn(x) -> x==pid end)
        rowNum = round(Float.floor(pid_index/n))
        colNum = rem(pid_index,n)
        neighbours = []

        if (rowNum == 0) || (rowNum == n-1) do        

          if (colNum == 0) || (colNum == n-1) do
            # Corner elements
            x = n - 1
            neighbours = case {rowNum, colNum} do
              {0, 0} -> [{0,1}, {1,0}]
              {0, x} -> [{0, x-1}, {1, x}]
              {x, 0} -> [{x-1, 0}, {x, 1}]
              {x, x} -> [{x, x-1}, {x-1, x}]
            end
          else
            # Row edge elements other than corner elements
            x = n - 1
            neighbours = case rowNum do
              0 -> [{0,colNum-1}, {0, colNum+1}, {1, colNum}]
              x -> [{x,colNum-1}, {x, colNum+1}, {x-1, colNum}]
            end
          end
        else
          if (colNum == 0 ) || (colNum == n-1) do
            # Column edge elements other than corner elements
            x = n - 1
            neighbours = case colNum do
              0 -> [{rowNum-1,0}, {rowNum+1, 0}, {rowNum, 1}]
              x -> [{rowNum-1,x}, {rowNum+1, x}, {rowNum, x-1}]
            end
          else
            # Inside elements
            x = n - 1
            neighbours = [{rowNum-1,colNum}, {rowNum+1, colNum}, {rowNum, colNum-1}, {rowNum, colNum+1}]
          end
        end

        # Get process IDs of the neighbours
        neighbour_process = for i <- neighbours do
          row = elem(i, 0)
          col = elem(i, 1)
          n_index = n * row + col
          n_pid = Enum.at(list_of_nodes, n_index)
        end

        remaining_nodes = list_of_nodes -- neighbour_process
        remaining_nodes = remaining_nodes -- [pid]
        # Add another random node as neighbour
        remaining_rand_nodes = Enum.random(remaining_nodes)
        neighbour_process = neighbour_process ++ [remaining_rand_nodes]
        # Return pid of a random neighbour
        n_pid = Enum.random(neighbour_process)
      end
  end
  
  # SERVER
  def init(messages) do
    {:ok, messages}
  end
  
  @doc """
  handle_cast method for GenServer.
  Send the rumour/push sum value to a random neighbour.
  """   
  def handle_cast({:send_rumour, rumour, list_of_nodes, topology}, state) do
    pid = self()
    if is_list(state) do
      # Push sum
      [count | s_w] = state
      rum_s = List.first(rumour)
      rum_w = List.last(rumour)
      state_s = List.first(s_w)
      state_w = List.last(s_w)
      new_state_s = (state_s + rum_s)
      new_state_w = (state_w + rum_w)

      if count < 3 do
        if ((new_state_s/new_state_w) - (state_s/state_w) <= :math.pow(10, -10)) do
          if ((count + 1) == 3) do
            spawn(fn -> send_rumours(pid, [rum_s, rum_w], list_of_nodes, topology) end)
            # Notify monitor server that actor is dead
            spawn(fn -> notify_process_dead(pid) end)
            {:noreply, [count + 1, state_s, state_w]}
          else
            spawn(fn -> send_rumours(pid, [new_state_s/2, new_state_w/2], list_of_nodes, topology) end)
            {:noreply, [count + 1, new_state_s/2, new_state_w/2]}
          end
        else
          spawn(fn -> send_rumours(pid, [new_state_s/2, new_state_w/2], list_of_nodes, topology) end)
          ## If s/w difference is not less than 10^-10 for consecutive rounds, 
          ## reset it to zero.
          {:noreply, [0, new_state_s/2, new_state_w/2]}
        end
      else
        # Dead node; simply forward the rumour to a neighbour.
        spawn(fn -> send_rumours(pid, [rum_s, rum_w], list_of_nodes, topology) end)
        {:noreply, [count, state_s, state_w]}
      end
    else
      #IO.inspect state
      if state <= 10 do
        if state == 10 do
          # Notify monitor server that actor is dead
          spawn(fn -> notify_process_dead(pid) end)
          {:noreply, state + 1}
        else
          spawn(fn -> send_rumours(pid, [], list_of_nodes, topology) end)
          {:noreply, state+1}
        end
      else
        {:noreply, state}
      end
    end
  end
  
  @doc """
  Notifies monitor server of dead actor.
  """ 
  def notify_process_dead(pid) do
    :global.sync()
    GenServer.cast(:global.whereis_name(@name), {:process_died, pid})
  end

end