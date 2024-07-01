from machine import Pin, SPI, UART, RTC
import max7219_8digit
import utime, time
import _thread

# Initialize SPI, UART for GPS, and RTC
spi = SPI(0, baudrate=10000000, polarity=1, phase=0, sck=Pin(2), mosi=Pin(3))
ss = Pin(5, Pin.OUT)
gpsModule = UART(1, baudrate=9600, tx=Pin(8), rx=Pin(9))
rtc = RTC()

# Change GPS module baud rate
changeBaudPacket = bytes([
    0xB5, 0x62, 0x06, 0x00, 0x14, 0x00, 
    0x01, 0x00, 0x00, 0x00, 0xD0, 0x08, 
    0x00, 0x00, 0x00, 0xC2, 0x01, 0x00, 
    0x07, 0x00, 0x03, 0x00, 0x00, 0x00, 
    0x00, 0x00, 0xC0, 0x7E
])
gpsModule.write(changeBaudPacket)
time.sleep(1)
gpsModule.init(115200, tx=Pin(8), rx=Pin(9))

FIX_STATUS = False
GPStime = ""

# Function to update RTC
def updateRTC(time_str):
    try:
        hour, minute, second = map(int, time_str.split(':'))
        rtc.datetime((2024, 7, 1, 0, hour, minute, second, 0))  # Example: Year 2024, July 1st
    except Exception as e:
        print("Failed to update RTC:", e)

# Function to get time from RTC and format it for display
def getRTCtime():
    datetime = rtc.datetime()
    return "{:02}:{:02}:{:02}".format(datetime[4], datetime[5], datetime[6])

# Function to get GPS data
def getGPS():
    global FIX_STATUS, GPStime
    
    while True:
        line = gpsModule.readline()
        if not line:
            continue
        
        buff = str(line)
        parts = buff.split(',')
        
        if len(parts) < 2:
            continue
        
        print(buff)
        
        if parts[0] == "$GPRMC" and parts[1]:
            GPStime = str(((int(parts[1][0:2]) + 3) % 24)) + ":" + parts[1][2:4] + ":" + parts[1][4:6]
        elif parts[0] == "$GPGLL" and len(parts) > 4 and parts[4]:
            GPStime = str(((int(parts[4][0:2]) + 3) % 24)) + ":" + parts[4][2:4] + ":" + parts[4][4:6]
        elif parts[0] == "$GPZDA" and len(parts) > 4 and parts[4]:
            GPStime = str(((int(parts[1][0:2]) + 3) % 24)) + ":" + parts[1][2:4] + ":" + parts[1][4:6]
        elif parts[0] == "b'$GPGGA" and len(parts) == 15:
            if parts[1] and parts[2] and parts[3] and parts[4] and parts[5] and parts[6] and parts[7]:
                GPStime = str(((int(parts[1][0:2]) + 3) % 24)) + ":" + parts[1][2:4] + ":" + parts[1][4:6]
                FIX_STATUS = True
                print("GPS fix acquired:", GPStime)
        
        utime.sleep_ms(10)

# Function to display time on the 7-segment display
def displayTime():
    display = max7219_8digit.Display(spi, ss)
    
    while True:
        if FIX_STATUS:
            updateRTC(GPStime)
        
        rtc_time = getRTCtime().replace(":", "-")
        display.write_to_buffer(rtc_time)
        display.display()
        utime.sleep(1)

# Thread to update GPS data
_thread.start_new_thread(getGPS, ())

# Main thread to update the display
displayTime()

