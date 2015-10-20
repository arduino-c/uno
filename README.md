UNO
===========

C project builder for Arduino Uno (rev3) (ATmega328p)

##Installation
	
	Install before: http://maxembedded.com/2015/06/setting-up-avr-gcc-toolchain-on-linux-and-mac-os-x/#step2

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


