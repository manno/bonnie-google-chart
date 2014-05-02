#!/usr/bin/ruby
require 'pp'

file= ARGV[0] || 'bonnie.csv'

module Parser
  require 'csv'

  # Bonnie 1.9
  HEADERS = [ 'vera', 'verb', 'name', 'conc', 'stz', 'sz', 'tta', 'outch', 'outchcpu', 'outblk', 'outblkcpu', 'outrw', 'outrwcpu', 'inch', 'inchcpu', 'inblk', 'inblkcpu', 'seek', 'seekcpu', 'ttb', 'ttc', 'ttd', 'tte', 'ttf', 'sc', 'sccpu', 'sr', 'srcpu', 'sd', 'sdcpu', 'rc', 'rccpu', 'rr', 'rrcpu', 'rd', 'rdcpu', 'latoutch', 'latoutblk', 'latoutrw', 'latinch', 'latinblk', 'latrand', 'latsc', 'latsr', 'latsd', 'latrc', 'latrr', 'latrd' ]
  # format_version,bonnie_version,name,concurrency,seed,file_size,io_chunk_size,putc,putc_cpu,put_block,put_block_cpu,rewrite,rewrite_cpu,getc,getc_cpu,get_block,get_block_cpu,seeks,seeks_cpu,num_files,max_size,min_size,num_dirs,file_chunk_size,seq_create,seq_create_cpu,seq_stat,seq_stat_cpu,seq_del,seq_del_cpu,ran_create,ran_create_cpu,ran_stat,ran_stat_cpu,ran_del,ran_del_cpu,putc_latency,put_block_latency,rewrite_latency,getc_latency,get_block_latency,seeks_latency,seq_create_latency,seq_stat_latency,seq_del_latency,ran_create_latency,ran_stat_latency,ran_del_latency
  #
  DURATION = /\A(\d+)([mu]s)\z/

  def self.parse_csv(file)
    results = Hash.new { |h,v| h[v] = [] }

    i = 0
    CSV.foreach(file) do |row|
      next unless row.count == HEADERS.count
      i = i + 1

      data = Hash[HEADERS.zip(row)]
      data.each do |k,v| 
        if v.nil? or v.empty? or v =~ /\A\++\z/ 
          v = 'null' 
        elsif match = v.match(DURATION)
          v = norm_time(match) || v
        elsif k == 'name'
          v = v + " #{i}"
        end
        results[k] << v
      end

    end

    results
  end

  def self.norm_time(match)
    case match[2]
    when /ms/
      "#{match[1].to_i * 1000 * 1000}"
    when /us/
      "#{match[1].to_i * 1000}"
    when /ns/
      "#{match[1].to_i}"
    end
  end

end

module Formatter
  require 'erb'

  TYPES = {
    'blockio' => {
      'name' => 'Block IO',
      'title' => 'kB/sec (higher is better)',
      'types' => [ 'outblk', 'outrw', 'inblk' ],
    },
    'metadata' => {
      'name' => 'File metadata',
      'title' => 'files/sec (higher is better)',
      'types' => [ 'sc', 'sd', 'rc', 'rd' ],
    },
    # 'metadata-read' => {
    #   'name' => 'File metadata (read)',
    #   'title' => 'files/sec (higher is better)',
    #   'types' => [ 'sr', 'rr' ],
    # },
    'blockio-cpu' => {
      'name' => 'Block IO CPU',
      'title' => 'CPU usage in % (lower is better)',
      'types' => [ 'outblkcpu', 'outrwcpu', 'inblkcpu', 'seekcpu' ],
    },
    'metadata-cpu' => {
      'name' => 'Seq and Random CPU',
      'title' => 'CPU usage in % (lower is better)',
      'types' => [ 'sccpu', 'srcpu', 'sdcpu', 'rccpu', 'rrcpu', 'rdcpu' ],
    },
    'blockio-latency' => {
      'name' => 'Block IO Latency',
      'title' => 'nanoseconds (lower is better)',
      'types' => [ 'latoutblk', 'latoutrw', 'latinblk' ],
    },
    'metadata-latency' => {
      'name' => 'File metadata Latency',
      'title' => 'nanoseconds (lower is better)',
      'types' => [ 'latsc', 'latsd', 'latrc', 'latrd' ],
    },
    'metadata-read-latency' => {
      'name' => 'File metadata (read) Latency',
      'title' => 'nanoseconds (lower is better)',
      'types' => [ 'latsr', 'latrr' ],
    },
  }

  LABELS = {
    'vera' => 'Version',
    'verb' => 'Version',
    'name' => 'Name',
    'conc' => 'Concurrency',
    'stz' => 'Unknown stz',
    'sz' => 'Size',
    'tta' => 'Empty tta',
    'outch' => 'Seq Char Output',
    'outchcpu' => 'Seq Char Output CPU',
    'outblk' => 'Seq Block Output',
    'outblkcpu' => 'Seq Block Output CPU',
    'outrw' => 'Block Rewrite',
    'outrwcpu' => 'Block Rewrite CPU',
    'inch' => 'Char Input',
    'inchcpu' => 'Char Input CPU',
    'inblk' => 'Block Input',
    'inblkcpu' => 'Block Input CPU',
    'seek' => 'Random Seek',
    'seekcpu' => 'Random Seek CPU',
    'ttb' => 'Empty ttb',
    'ttc' => 'Empty ttc',
    'ttd' => 'Empty ttd',
    'tte' => 'Empty tte',
    'ttf' => 'Empty ttf',
    'sc' => 'Seq Create',
    'sccpu' => 'Seq Create CPU',
    'sr' => 'Seq Read',
    'srcpu' => 'Seq Read',
    'sd' => 'Seq Delete',
    'sdcpu' => 'Seq Delete CPU',
    'rc' => 'Random Create',
    'rccpu' => 'Random Create CPU',
    'rr' => 'Random Read',
    'rrcpu' => 'Random Read CPU',
    'rd' => 'Random Delete',
    'rdcpu' => 'Random Delete CPU',
    'latoutch' => 'Latency Char Output',
    'latoutblk' => 'Latency Block Output',
    'latoutrw' => 'Latency Rewrite',
    'latinch' => 'Latency Input Char',
    'latinblk' => 'Latency Input Block',
    'latrand' => 'Latency Random seek',
    'latsc' => 'Latency Seq Create',
    'latsr' => 'Latency Seq Read',
    'latsd' => 'Latency Seq Delete',
    'latrc' => 'Latency Random Create',
    'latrr' => 'Latency Random Read',
    'latrd' => 'Latency Random Delete',
  }

  class OnePage

    attr_reader :results

    def initialize(results)
      @results = results
    end

    def render
      template = ERB.new template_string
      template.result binding
    end

    private

    def template_string
      template = <<EOF
<html>
  <head>
  <title>bonnie2gchart</title>
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
    <script type="text/javascript" src="https://www.google.com/jsapi"></script>
    <script type="text/javascript">
      google.load("visualization", "1", {packages:["corechart"]});
      google.setOnLoadCallback(drawChart);

      <% TYPES.keys.each do |type| %>
      function draw_<%= type.gsub(/-/, '_') %>() {
        var data = new google.visualization.DataTable();
        data.addColumn('string', 'Tests');
        <% results['name'].each do |name| %>
        data.addColumn('number', '<%= name %>'); <% end %>
        <% TYPES[type]['types'].each do |label| %>
        data.addRows([['<%= LABELS[label] %>', <%= results[label].join(', ') %>]]); <% end %>

        var options = {
          title: '<%= TYPES[type]['title'] %>',
          vAxis: {title: '<%= TYPES[type]['name'] %>',  titleTextStyle: {color: 'red'}}
        };

        var chart = new google.visualization.BarChart(document.getElementById('chart_div_<%= type %>'));
        chart.draw(data, options);
      }
      <% end %>

      function drawChart() {
      <% TYPES.keys.each do |type| %>
        draw_<%= type.gsub(/-/, '_') %>();<% end %>
      }
    </script>
  </head>

  <body>
    <% TYPES.each do |type, meta| %>
    <h2><%= meta['name'] %></h2>
    <div id="chart_div_<%= type %>" style="width: 900px; height: 500px;"></div> <% end %>
  </body>
</html>
EOF
      template
    end
  end

end

results = Parser::parse_csv(file)
formatter = Formatter::OnePage.new(results)
puts formatter.render

