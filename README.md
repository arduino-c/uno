UNO
===========

C project builder for Arduino Uno (rev3) (ATmega328p)

##Installation
	git clone https://github.com/arduino-c/uno
	cd uno
	sudo ./install

##Usage
```shell
	uno new MYPROJECT
	cd MYPROJECT
    uno import adc gpio uart uart_stdio spi eeprom
	# write your code
	make # for compile & upload program
    make tty # for start serial connection with board
```


