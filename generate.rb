
require 'fileutils'
require 'erb'

KINDS = %w(drum perc bass chord lead)

class Slot

  attr_reader :kind, :ident
  def initialize(kind, ident)
    @kind = kind
    @ident = ident
  end

  def to_s
    [@kind, suffix].join('_')
  end

  def suffix
    if @ident.is_a?(Integer)
      "%02d" % @ident          
    else
      @ident.to_s
    end
  end

end

class Interface

  def initialize(scripts)
    @scripts = scripts
  end

  def write!
    FileUtils.mkdir_p(File.dirname(filename))
    File.open(filename, 'w') { |f| f.write(template.result(binding)) }
  end

  def grid
    @grid ||= calculate_grid
  end

  def find_stop(script)
    stop_name = script.slot.kind + "_stop"
    @scripts.find { |s| s.name == stop_name }
  end

  def each_row(&block)
    size = @grid.first[:scripts].length
    (0...size).each do |offset|
      scripts = @grid.map { |column| column[:scripts][offset] }
      block.call(scripts)
    end
  end

  private

  def filename
    File.expand_path('../build/web/hibbard.html', __FILE__)
  end

  def template
    ERB.new(File.read(File.expand_path('../templates/interface.html.erb', __FILE__)))
  end  

  def calculate_grid
    KINDS.map do |kind|
      {
        kind: kind,
        scripts: @scripts.select { |s| s.slot.kind == kind }.sort_by { |script| script.slot.ident.is_a?(Integer) ? script.slot.ident : 0 }
      }
    end
  end

end

class Script

  attr_reader :name, :slot
  attr_accessor :command_id
  def initialize(slot, note)
    @slot = slot
    @note = note
    @name = slot.to_s
  end

  def filename
    @filename ||= File.expand_path("../build/scripts/#{@slot}.lua", __FILE__)
  end

  def write!
    FileUtils.mkdir_p(File.dirname(filename))
    File.open(filename, 'w') { |f| f.write(template.result(binding)) }
  end

  private

  def template
    ERB.new(File.read(File.expand_path('../templates/slot.lua.erb', __FILE__)))
  end

end

class Generator

  SLOT_COUNT = 5
  START_NOTE = 21

  def self.run
    new.generate!
  end

  def generate_scripts
    scripts.each(&:write!)
  end

  def generate_interface(actionlist)
    # Add commands to scripts
    pattern = slots.map(&:to_s).join('|')
    File.read(actionlist).scan(/(_RS\S+)\s+Script:\s+(#{pattern})\.lua/).each do |(cmd, name)|
      script = scripts.find { |s| s.name == name }
      if !script
        raise "Could not find script matching #{name}"
      end
      if script
        script.command_id = cmd
      end
    end
    Interface.new(scripts).write!
  end

  def scripts
    @scripts ||= calculate_scripts
  end

  def slots    
    @slots ||= calculate_slots
  end

  private

  def calculate_slots
    KINDS.flat_map do |kind|
      stop = Slot.new(kind, :stop)
      starts = SLOT_COUNT.times.map { |i| Slot.new(kind, i + 1) }
      starts.insert(0, stop)
    end
  end

  def calculate_scripts
    slots.map.with_index do |slot, index|
      Script.new(slot, START_NOTE + index)
    end
  end

end

generator = Generator.new

if ARGV[0]
  generator.generate_interface(ARGV[0])
else
  generator.generate_scripts
end