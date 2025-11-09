LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

PACKAGE common_pkg IS
    CONSTANT C_ARTY_A7_CLK_FREQ : INTEGER := 100e6;
    FUNCTION to_string (a : STD_LOGIC_VECTOR) RETURN STRING;
    
    TYPE rom_type2 IS ARRAY (0 TO 14) OF STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL register_config_rom2 : rom_type2 := (
        --source https://github.com/AngeloJacobo/FPGA_OV7670_Camera_Interface/blob/main/src/camera_interface.v
        -- Reset everything
x"12_80", -- COM7: reset all regs; wait ~1–5 ms  :contentReference[oaicite:0]{index=0}

-- Clocking
x"11_80", -- CLKRC: use external clock directly (no prescale)  :contentReference[oaicite:1]{index=1}
x"6B_00", -- DBLV: PLL bypass (default is 0x0A=×4; 0x00 is OK too)  :contentReference[oaicite:2]{index=2}

-- Put output to RGB565, full range
x"12_04", -- COM7: RGB (bit2=1), not RAW  :contentReference[oaicite:3]{index=3}
x"8C_00", -- RGB444: disable RGB444  :contentReference[oaicite:4]{index=4}
x"40_D0", -- COM15: full [00..FF] output + RGB565  :contentReference[oaicite:5]{index=5}
x"3A_00", -- TSLB: leave YUV byte swap OFF; normal output (safe for RGB)  :contentReference[oaicite:6]{index=6}

-- Quiet the pixel clock in blanking (helps FIFOs)
x"15_20", -- COM10: PCLK does not toggle during H-blank (bit5=1)  :contentReference[oaicite:7]{index=7}

-- Enable downsample/scaler and run it manually
x"0C_0C", -- COM3: DCW enable (bit2=1) + Scale enable (bit3=1)  :contentReference[oaicite:8]{index=8}
x"3E_1A", -- COM14: manual scaling (bit3=1) + use scaled PCLK divider (bit4=1), /4 (bits2:0=010)  :contentReference[oaicite:9]{index=9}

-- Choose QQVGA (÷4 both directions)
x"72_22", -- SCALING_DCWCTR: v ÷4 (bits5:4=10), h ÷4 (bits1:0=10); rounding off to start  :contentReference[oaicite:10]{index=10}
-- (Optional nicer look: use 0xEE here to turn ON vertical/horizontal rounding & averaging bits.)  :contentReference[oaicite:11]{index=11}

-- Match divider setting above
x"73_02", -- SCALING_PCLK_DIV: /4 on the scaled path  :contentReference[oaicite:12]{index=12}

-- Keep factory scaler coeffs (good defaults)
x"70_3A", -- SCALING_XSC  :contentReference[oaicite:13]{index=13}
x"71_35", -- SCALING_YSC  :contentReference[oaicite:14]{index=14}

-- Leave the auto controls ON for first light
x"13_8F"  -- COM8: AEC/AGC/AWB enable  :contentReference[oaicite:15]{index=15}

      ); 
      
      -- reset (do this separately, then delay ~50ms):
-- write(16#12#, 16#80#);
TYPE rom_type IS ARRAY (0 TO 14) OF STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL register_config_rom : rom_type := (
-- then:
x"12_80", -- soft reset
x"3E_00", -- COM14: no scaling, normal pclk , ALSO DEFAULT
x"6b_40", -- by pass PLL and use directly the external clock which is 24 MHz coming from the fpga
x"11_09", -- use external clock directly
x"15_00", -- default for free running pclk
x"8C_00", -- RGB444: disable
x"40_C0", -- COM15: full 0..FF, no RGB565 force
x"12_01", -- COM7: RAW Bayer 8-bit
-- windowing for 640x480 (your values are fine)
x"17_13", 
x"18_01", 
x"32_6b", 
x"19_02", 
x"1A_7A", 
x"03_0A",
-- finally FORCE RAW:

x"12_01"  -- COM7: RAW Bayer (1 sample per PCLK)
); 
 
      
      
        TYPE rom_type4 IS ARRAY (0 TO 76) OF STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL register_config_rom4 : rom_type4 := (
        --source https://github.com/AngeloJacobo/FPGA_OV7670_Camera_Interface/blob/main/src/camera_interface.v
        x"12_01", --04set output format to RGB - it is already coming in RGB , and not RAW
        x"15_20", --pclk will not toggle during horizontal blank
        x"40_C0", --RGB565 --output range from 00 to FF
        --RGB444 
        x"8C_00", -- maybe I dont want RGB444
        --x"6b4a", --PLL control input clock x4
        -- x"3E12", --PCLK divider by 4
        --x"11_01", -- this is a clock divider by 2 ??? needed ?
        x"6B_4A", -- input clock times 4 ??
        --x"12_04", -- 12_04 COM7,     set RGB color output --- THEN AGAIN 12
        --x"11_80", -- CLKRC     internal PLL matches input clock
        x"0C_0C", --00 COM3,     default settings ---------------------------------- 
        x"3E_00", -- COM14,    no scaling, normal pclock
        x"04_00", -- COM1,     disable CCIR656
        x"40_E0", --D0 COM15,     RGB565, full output range
        x"3e_18",
        x"3a_04", --TSLB       set correct output data sequence (magic)
        x"14_18", --COM9       MAX AGC value x4 0001_1000
        x"4F_B3", --MTX1       all of these are magical matrix coefficients
        x"50_B3", --MTX2
        x"51_00", --MTX3
        x"52_3D", --MTX4
        x"53_A7", --MTX5
        x"54_E4", --MTX6
        x"58_9E", --MTXS
        x"3D_C0", --COM13      sets gamma enable, does not preserve reserved bits, may be wrong?
        --x"17_14", --HSTART     start high 8 bits ORIG
        x"17_16", --HSTART MSB  
        --x"18_02", --HSTOP      stop high 8 bits --these kill the odd colored line
        x"18_04",
        x"32_80", --HREF       edge offset
        --x"19_03", --VSTART     start high 8 bits
        x"19_02",
        --x"1A_7B", --VSTOP      stop high 8 bits
        x"1A_7A",
        x"03_0A", --VREF       vsync edge offset
        x"0F_41", --COM6       reset timings
        x"1E_00", --MVFP       disable mirror / flip --might have magic value of 03
        x"33_0B", --CHLF       --magic value from the internet
        x"3C_78", --COM12      no HREF when VSYNC low
        x"69_00", --GFIX       fix gain control
        x"74_00", --REG74      Digital gain control
        x"B0_84", --RSVD       magic value from the internet *required* for good color
        x"B1_0c", --ABLC1
        x"B2_0e", --RSVD       more magic internet values
        x"B3_80", --THL_ST --begin mystery scaling numbers
        x"70_3a",
        x"71_35",
        x"72_6B", --11
        x"73_00", --f0
        x"a2_02", --gamma curve values
        x"7a_20",
        x"7b_10",
        x"7c_1e",
        x"7d_35",
        x"7e_5a",
        x"7f_69",
        x"80_76",
        x"81_80",
        x"82_88",
        x"83_8f",
        x"84_96",
        x"85_a3",
        x"86_af",
        x"87_c4",
        x"88_d7",
        x"89_e8", --AGC and AEC
        x"13_e0", --COM8, disable AGC / AEC
        x"00_00", --set gain reg to 0 for AGC
        x"10_00", --set ARCJ reg to 0
        x"0d_40", --magic reserved bit for COM4
        x"14_18", --COM9, 4x gain + magic bit
        x"a5_05", -- BD50MAX
        x"ab_07", --DB60MAX
        x"24_95", --AGC upper limit
        x"25_33", --AGC lower limit
        x"26_e3", --AGC/AEC fast mode op region
        x"9f_78", --HAECC1
        x"a0_68", --HAECC2
        x"a1_03", --magic
        x"a6_d8", --HAECC3
        x"a7_d8", --HAECC4
        x"a8_f0", --HAECC5
        x"a9_90", --HAECC6
        x"aa_94", --HAECC7
        x"13_e5", --COM8, enable AGC / AEC
        --x"1E_23", --Mirror Image
        x"69_06" --gain of RGB(manually adjusted)
        -- x"71_B5" --test pattern
    ); 
    

    TYPE rom_type3 IS ARRAY (0 TO 77) OF STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL register_config_rom3 : rom_type3 := (
        --source https://github.com/AngeloJacobo/FPGA_OV7670_Camera_Interface/blob/main/src/camera_interface.v
        x"12_01", --04set output format to RGB - it is already coming in RGB , and not RAW
        x"15_20", --pclk will not toggle during horizontal blank
        x"40_d0", --RGB565 --output range from 00 to FF
        --RGB444 
        x"8C_02", -- maybe I dont want RGB444
        --x"6b4a", --PLL control input clock x4
        -- x"3E12", --PCLK divider by 4
        --x"11_01", -- this is a clock divider by 2 ??? needed ?
        x"6B_4A", -- input clock times 4 ??
        x"12_04", -- 12_04 COM7,     set RGB color output --- THEN AGAIN 12
        --x"11_80", -- CLKRC     internal PLL matches input clock
        x"0C_0C", --00 COM3,     default settings ---------------------------------- 
        x"3E_00", -- COM14,    no scaling, normal pclock
        x"04_00", -- COM1,     disable CCIR656
        x"40_E0", --D0 COM15,     RGB565, full output range
        x"3e_18",
        x"3a_04", --TSLB       set correct output data sequence (magic)
        x"14_18", --COM9       MAX AGC value x4 0001_1000
        x"4F_B3", --MTX1       all of these are magical matrix coefficients
        x"50_B3", --MTX2
        x"51_00", --MTX3
        x"52_3D", --MTX4
        x"53_A7", --MTX5
        x"54_E4", --MTX6
        x"58_9E", --MTXS
        x"3D_C0", --COM13      sets gamma enable, does not preserve reserved bits, may be wrong?
        --x"17_14", --HSTART     start high 8 bits ORIG
        x"17_16", --HSTART MSB  
        --x"18_02", --HSTOP      stop high 8 bits --these kill the odd colored line
        x"18_04",
        x"32_80", --HREF       edge offset
        --x"19_03", --VSTART     start high 8 bits
        x"19_02",
        --x"1A_7B", --VSTOP      stop high 8 bits
        x"1A_7A",
        x"03_0A", --VREF       vsync edge offset
        x"0F_41", --COM6       reset timings
        x"1E_00", --MVFP       disable mirror / flip --might have magic value of 03
        x"33_0B", --CHLF       --magic value from the internet
        x"3C_78", --COM12      no HREF when VSYNC low
        x"69_00", --GFIX       fix gain control
        x"74_00", --REG74      Digital gain control
        x"B0_84", --RSVD       magic value from the internet *required* for good color
        x"B1_0c", --ABLC1
        x"B2_0e", --RSVD       more magic internet values
        x"B3_80", --THL_ST --begin mystery scaling numbers
        x"70_3a",
        x"71_35",
        x"72_6B", --11
        x"73_00", --f0
        x"a2_02", --gamma curve values
        x"7a_20",
        x"7b_10",
        x"7c_1e",
        x"7d_35",
        x"7e_5a",
        x"7f_69",
        x"80_76",
        x"81_80",
        x"82_88",
        x"83_8f",
        x"84_96",
        x"85_a3",
        x"86_af",
        x"87_c4",
        x"88_d7",
        x"89_e8", --AGC and AEC
        x"13_e0", --COM8, disable AGC / AEC
        x"00_00", --set gain reg to 0 for AGC
        x"10_00", --set ARCJ reg to 0
        x"0d_40", --magic reserved bit for COM4
        x"14_18", --COM9, 4x gain + magic bit
        x"a5_05", -- BD50MAX
        x"ab_07", --DB60MAX
        x"24_95", --AGC upper limit
        x"25_33", --AGC lower limit
        x"26_e3", --AGC/AEC fast mode op region
        x"9f_78", --HAECC1
        x"a0_68", --HAECC2
        x"a1_03", --magic
        x"a6_d8", --HAECC3
        x"a7_d8", --HAECC4
        x"a8_f0", --HAECC5
        x"a9_90", --HAECC6
        x"aa_94", --HAECC7
        x"13_e5", --COM8, enable AGC / AEC
        --x"1E_23", --Mirror Image
        x"69_06" --gain of RGB(manually adjusted)
        -- x"71_B5" --test pattern
    );
END PACKAGE;

PACKAGE BODY common_pkg IS
    FUNCTION to_string (a : STD_LOGIC_VECTOR) RETURN STRING IS
        VARIABLE b : STRING (1 TO a'length) := (OTHERS => NUL);
        VARIABLE stri : INTEGER := 1;
    BEGIN
        FOR i IN a'RANGE LOOP
            b(stri) := STD_LOGIC'image(a((i)))(2);
            stri := stri + 1;
        END LOOP;
        RETURN b;
    END FUNCTION;

END common_pkg;