#!RUBY

require 'yaml'

$repo = 'REPO'

$config_name = '.config.yml'

$sys = 'System' # 'Linux', 'Darwin', etc. See install script

# set up there your tty (virtual com-port)
$default_tty = {'Darwin' => '/dev/tty.usbmodem1411', 'Linux' => '/dev/ttyACM0'}




def makefile_create()

  cfg = load_config

  tty = $default_tty[$sys]
  params = {
  target: 'main',
  gcc_mcu: 'atmega328p',
  tty: tty,
  tty_baud: 9600,
  cflags: '-mmcu=$(MCU) -Wall -g -Os -lm  -mcall-prologues -I./lib',
  ldflags: '-mmcu=$(MCU)  -Wall -g -Os',
  symbols: '-DF_CPU=16000000UL',
  dude_mcu: 'm328p',
  dude_prg: 'arduino',
  dude_baud: 115200,
  dude_serial: tty,
  clean: '*.o *.s *.elf *.bin',
}

  src_list = ""
  obj_list = ""
  inc_paths = ""
  cfg[:sources].each do |srcname|
    src_list += srcname + ' '
    bare_name = srcname.split('/')[-1]
    bare_name[-1] = 'o'
    obj_list += bare_name + ' '
  end

  cfg[:modules].each do |modname|
    inc_paths << " -Ilib/#{modname} "
  end


mk_text = """
.PHONY: all clean
SRC = #{src_list}
OBJS = #{obj_list}
TARGET = #{params[:target]}
MCU = #{params[:gcc_mcu]}
CC = avr-gcc
OBJCOPY = avr-objcopy
CFLAGS = #{params[:cflags]} #{inc_paths}
LDFLAGS = #{params[:ldflags]}
SYMBOLS = #{params[:symbols]}
CLEAN = #{params[:clean]}

all:
\tmake $(TARGET).hex
\tmake flash
\tmake clean

$(TARGET).elf:
\t$(CC) $(CFLAGS) $(SYMBOLS) -c $(SRC)
\t$(CC) $(LDFLAGS) -o $(TARGET).elf  $(OBJS) -lm

$(TARGET).bin: $(TARGET).elf
\t$(OBJCOPY) -O binary -R .eeprom -R .nwram $(TARGET).elf $(TARGET).bin

$(TARGET).hex: $(TARGET).bin
\t$(OBJCOPY) -O ihex -R .eeprom -R .nwram  $(TARGET).elf $(TARGET).hex

clean:
\trm -rf $(CLEAN)


# Serial console to target
TTY = #{params[:tty]}
TTY_BAUD = #{params[:tty_baud]}

tty:
\tminicom -D$(TTY) -b$(TTY_BAUD)

# dude
DUDE_BAUD = #{params[:dude_baud]}
DUDE_MCU = #{params[:dude_mcu]}
DUDE_PROGRAMMER = #{params[:dude_prg]}
DUDE_SERIAL = #{params[:dude_serial]}

erase:
\t#todo

flash:
\tavrdude -p $(DUDE_MCU) -c $(DUDE_PROGRAMMER) -P $(DUDE_SERIAL) -b $(DUDE_BAUD) -U flash:w:$(TARGET).hex
"""

  create_file 'Makefile', text: mk_text, overwrite: true
end


def config_init()
  store_config({modules: [], headers: [], sources: []})
end

def load_config()
  f = File.open($config_name, 'r')
  y = YAML.load(f.read())
  f.close
  return y
end

def store_config(cfg)
  f = File.open($config_name, 'w')
  f.write cfg.to_yaml
  f.close
end

def config_add_source(name)
  cfg = load_config
  cfg[:sources].push name
  store_config cfg
end

def config_add_header(name)
  cfg = load_config
  cfg[:headers].push name
  store_config cfg
end

def config_add_module(name)
  cfg = load_config
  cfg[:modules].push name
  cfg[:sources].push "lib/#{name}/#{name}.c"
  cfg[:headers].push "#{name}.h"
  store_config cfg
end


# :type :place :text :comment :overwrite
def create_file(name, *args)
  par = args[0]

  text = ""
  tag = name

  if par.include? :text
    text = par[:text]
  end

  if par.include? :place
    name = par[:place] + '/' + name
  end

  if par.include? :type
    if par[:type] == '.c'
      name = name + '.c'

      if par.include? :comment
        comment = par[:comment]
      else
        comment = "/*\n * #{name}\n */"
      end

      text = comment + "\n" + text

      if not File.exist? name
        config_add_source name
      end

    elsif par[:type] == '.h'
      tag = tag.upcase + '_H'
      name = name + '.h'

      if par.include? :comment
        comment = par[:comment]
      else
        comment = "/*\n * #{name}\n */"
      end

      text = comment + "\n" +
"""
#ifndef #{tag}
#define #{tag}

#{text}

#endif /* #{tag} */
"""
      # check if exist & already in config
      if not File.exist? name
        config_add_header name
      end
    end
  end

  # check if exist
  if File.exist? name
    if par.include? :overwrite
      if par[:overwrite]
        File.delete name
      else
        puts "FAIL: file '#{name}' already exist."
        exit
      end
    else
      puts "FAIL: file '#{name}' already exist."
        exit
    end
    puts "\trefresh #{name}"
  else
    puts "\tcreate #{name}"
  end

  f = File.new(name, 'w')
  f.write text
  f.close
end




def main_create(modules)
  includes = ""
  includes << "#include <stdio.h>\n"
  includes << "#include <avr/io.h>\n"
  includes << "#include <util/delay.h>\n"
  includes << "\n"
  includes << "#include \"init.h\"\n"
  modules.each do |modname|
    includes << "#include <#{modname}.h>\n"
  end

  main_text = """
#{includes}

int main() {
	init();
	while(1) {
		/*
		 * before uncomment this example add uart, uart_stdio and gpio modules:
		 * $ avr import uart uart_stdio gpio
		 */

		/*
		printf(\"tick! \\n\");
		gpio_out(&PORTB, PB5, 0xFF);
		_delay_ms(666);

		printf(\"tuck! \\n\");
		gpio_out(&PORTB, PB5, 0x00);
		_delay_ms(666);
		*/
	}
	return 0;
}\n
"""

  create_file('main', type: '.c', overwrite: true, text: main_text)
end

def init_create(modules)

  includes = ""
  init_calls = ""

  includes << "#include <stdio.h>\n"
  includes << "#include <avr/io.h>\n"
  includes << "#include <util/delay.h>\n"

  modules.each do |modname|
    init_calls << "\t#{modname}_init();\n"
    includes << "#include <#{modname}.h>\n"
  end

  init_text = """
#{includes}

int init() {
#{init_calls}
    /* before uncomment add uart, uart_stdio and gpio modules */
	/*gpio_dir(&DDRB, PB5, GPIO_DIR_OUT);
	printf(\"system init ok\\n\");*/
	return 0;
}\n
"""

  create_file('init', place: '.', type: '.c', overwrite: true, text: init_text)
  create_file('init', place: '.', type: '.h', overwrite: true, text: "int init();")
end


def create_project(name, required)

  # check if already exist
  if Dir.exist? name
    print "Directory already exist, Overwrite? (n/y): "
    if STDIN.gets != "y\n"
      exit
    end
    puts "removing.."
    system("rm -rf #{name}")
  end

  puts "creating of new project \'#{name}\'.."
  Dir.mkdir name
  Dir.chdir name

  `git init`

  create_file('README.md', text: "\n##{name}\n\n")
  system("#{$editor} README.md")

  config_init()

  Dir.mkdir 'lib'
  required.each do |modname|
    add_module modname
  end

  modules = load_config()[:modules]

  init_create(modules)
  main_create(modules)
  makefile_create
end

def project_refresh()
  modules = load_config()[:modules]

  init_create(modules)
  main_create(modules)
end


def add_module(name)
  #clone module to lib
  Dir.chdir 'lib'
  system("git clone #{$repo}/#{name}")
  Dir.chdir '..'

  config_add_module name

  project_refresh()
end


# add existing file to project
def append_file(name)
  puts "append file: #{name}"
  config_add_source name
end

#add existing dir for project
def append_dir(name)
  puts "append folder: #{name}"
end

def main()
  cmd = ARGV[0]

  if cmd == 'new'
	name = ARGV[1]
	modules = ARGV[2..-1]
    create_project name, []
  elsif cmd == 'import'
    modules = ARGV[1..-1]
    modules.each do |modname|
      add_module modname
    end
  elsif cmd == 'append'
    dir_or_files = ARGV[1..-1]
    dir_or_files.each do |dir_or_file|
      if Dir.exist? dir_or_file
        append_dir dir_or_file
      elsif File.exist? dir_or_file
        append_file dir_or_file
      else
        puts "file #{dir_or_file} not exist"
      end
    end
  end
end

if ARGV[0]
  main()
else
  #puts "avr new <project_name>"
  #puts "avr import module1 module2 .."
  #puts "avr append file directory .."

  puts "unknown command; usage example:"
  puts "avr new my_project"
  puts "cd my_project"
  puts "avr import uart gpio"
  puts "touch mycode.c"
  puts "append mycode.c"
end

if File.exist? $config_name
   makefile_create()
end
