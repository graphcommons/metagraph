#! /bin.ruby

require "unidecoder"
require "graphcommons"

# Check if API key is loaded from environment
unless Graphcommons::API.check_key
  puts "Please paste your API key here:"
  $apikey = gets.sub(/\n$/,"")
  Graphcommons::API.set_key $apikey
  puts
end

# Get ID of target hub
puts "Please paste the ID of Graphcommons hub:"
hubid = gets.sub(/\n$/,"")
hub = Graphcommons::API.get :hubs, :id=>hubid
unless hub["msg"] == "Hub not found"
  name = hub["name"]
  slug = name.to_ascii.downcase.gsub(/\s/,"-").gsub(/[^a-z-]/,"")
  puts "Hub found: #{name}"
  puts
else
  puts "Hub not found"
  exit 0
end

graphs = []
signals = []

# Search for detailed (node) info through hub's graphs
Graphcommons::API.get("graphs/search", :hub=>hubid, :limit=>20).each do |g|
  gr = Graphcommons::API.get(:graphs, :id=>g["id"])["graph"]
  graphs << {
    :name => gr["name"],
    :nodes => gr["nodes"].map {|u| u["name"].to_ascii.downcase.gsub(/\W/,"") } 
  }
  puts "Getting graph data: #{gr["name"]}"
end
puts "Graphs downloaded."
puts

# Create node creation signals
graphs.each_with_index do |graph,index|
  signals << {
    :action => :node_create,
    :name => graph[:name],
    :type => "graph",
    :properties => {:frequency=>graph[:nodes].count}
  }
end

# Create edge creation signals
checked = []
graphs.each_with_index do |source,index|
  checked << index
  graphs.each_with_index do |target,ind|
    next if checked.include? ind
    signals << {
      :action => :edge_create,
      :from_name => source[:name],
      :from_type => "graph",
      :to_name => target[:name],
      :to_type => "graph",
      :name => "common nodes",
      :weight => (source[:nodes] & target[:nodes] || []).length
    }
  end
end

# Send signals to API, create graph with content thanks to signal API
puts "Creating graph #{name} - Metagraph"
graph = Graphcommons::Endpoint.new_graph :name => "#{name} - Metagraph", :status => 0, :description => "Graph of graphs generated from #{name} hub.", :signals => signals
puts

puts "All is well. Do you want to see the signal? (y/n)"
if gets.match(/y/)
  pp graph
end

puts
puts "You can visit your graph at https://graphcommons.com/graphs/#{graph["graph"]["id"]}"

# Old version: prepare CSV files for importing
def generate_csv
  require "csv"
  CSV.open("ma-nodes.csv","w") do |csv|
    header = ["Type","Name","Description","Image","Reference","Frequency"]
    csv << header
    graphs.each_with_index do |graph,index|
      csv << ["Graph",graph[:name],"","","",graph[:nodes].count]
    end
  end

  CSV.open("ma-edges.csv","w") do |csv|
    header = ["Node Type","Node Name","Edge Type","Node Type","Node Name","Weight"]
    csv << header
    checked = []
    graphs.each_with_index do |source,index|
      checked << index
      graphs.each_with_index do |target,ind|
        next if checked.include? ind
        csv << ["Graph",source[:name],:nodes,"Graph",target[:name],(source[:nodes] & target[:nodes] || []).length]
      end
    end
  end
  puts "CSV files successfully generated."
  exit 0
end


