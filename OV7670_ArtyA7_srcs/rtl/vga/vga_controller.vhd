LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY vga_controller IS
generic(
        G_I_WIDTH : integer    := 160; --160 320 640
        G_I_HEIGHT : integer   := 120; --120 240 480
        G_I_WIDTH_T : integer  := 160; --160 320 640
        G_I_HEIGHT_T : integer := 120; --120 240 480
        G_I_NBITS  : integer   := 15
    );
    PORT (
        rst : IN STD_LOGIC;
        pxl_clk : IN STD_LOGIC;
        VGA_HS_O : OUT STD_LOGIC;
        VGA_VS_O : OUT STD_LOGIC;
        VGA_R : OUT STD_LOGIC_VECTOR (3 DOWNTO 0);
        VGA_B : OUT STD_LOGIC_VECTOR (3 DOWNTO 0);
        VGA_G : OUT STD_LOGIC_VECTOR (3 DOWNTO 0);

        start : IN STD_LOGIC;

        --frame_buffer signals
        addrb : OUT STD_LOGIC_VECTOR(G_I_NBITS -1 DOWNTO 0);
        web   : out std_logic;
        doutb : IN STD_LOGIC_VECTOR(11 DOWNTO 0) --pixel data
    );
END vga_controller;

ARCHITECTURE rtl OF vga_controller IS
    --***640x480@60Hz***--  Requires 25 MHz clock
    CONSTANT FRAME_WIDTH : NATURAL := G_I_WIDTH; --640; --640
    CONSTANT FRAME_HEIGHT : NATURAL := G_I_HEIGHT; --480;  --480

    CONSTANT H_FRONT_PORCH : NATURAL      := 16;--88;     --16; --H front porch width (pixels)
    CONSTANT H_SYNC_PULSE_WIDTH : NATURAL := 96;--44;--96; --H sync pulse width (pixels)
    CONSTANT H_TOTAL_LINE : NATURAL       := G_I_WIDTH_T; --2200;    --800; --H total period (pixels) 

    CONSTANT V_FRONT_PORCH : NATURAL :=   10; --  4;      --10; --vertical front porch width (lines)
    CONSTANT V_SYNC_PULSE_WIDTH : NATURAL := 2; -- 5; --2; --vertical sync pulse width (lines)
    CONSTANT V_MAX_LINE : NATURAL :=      G_I_HEIGHT_T;       --1125;      --525; --vertical total period (lines)

    CONSTANT H_POL : STD_LOGIC := '0';
    CONSTANT V_POL : STD_LOGIC := '0';

    SIGNAL hsync_reg, hsync_next : INTEGER RANGE 0 TO H_TOTAL_LINE - 1 := 0;
    SIGNAL vsync_reg, vsync_next : INTEGER RANGE 0 TO V_MAX_LINE - 1 := 0;

    SIGNAL bram_address_reg, bram_address_next : unsigned(G_I_NBITS -1 DOWNTO 0) := (OTHERS => '0');

    SIGNAL line_finished : STD_LOGIC := '0';
    SIGNAL frame_finished : STD_LOGIC := '0';

BEGIN
    addrb <= STD_LOGIC_VECTOR(bram_address_reg);

    hsync_next <= 0 WHEN line_finished = '1' AND start = '1' ELSE
        hsync_reg + 1 WHEN start = '1' ELSE
        hsync_reg;

    line_finished <= '1' WHEN hsync_reg = H_TOTAL_LINE - 1 ELSE
        '0';

    VGA_HS_O <= '0' WHEN hsync_reg >= (H_FRONT_PORCH + FRAME_WIDTH) AND hsync_reg < (H_FRONT_PORCH + FRAME_WIDTH + H_SYNC_PULSE_WIDTH) ELSE
        '1'; --HSync Timing

    VGA_VS_O <= '0' WHEN vsync_reg >= (V_FRONT_PORCH + FRAME_HEIGHT) AND vsync_reg < (V_FRONT_PORCH + FRAME_HEIGHT + V_SYNC_PULSE_WIDTH) ELSE
        '1'; --VSync timing

    frame_finished <= '1' WHEN vsync_reg = V_MAX_LINE - 1 ELSE
        '0';

    vga_r <= doutb(5 DOWNTO 2) WHEN hsync_reg >= 0 AND vsync_reg >= 0 AND hsync_reg < FRAME_WIDTH AND vsync_reg < FRAME_HEIGHT ELSE --left upper corner
        "0000";
    vga_g <= doutb(5 DOWNTO 2) WHEN hsync_reg >= 0 AND vsync_reg >= 0 AND hsync_reg < FRAME_WIDTH AND vsync_reg < FRAME_HEIGHT ELSE --left upper corner
        "0000";
    vga_b <= doutb(5 DOWNTO 2) WHEN hsync_reg >= 0 AND vsync_reg >= 0 AND hsync_reg < FRAME_WIDTH AND vsync_reg < FRAME_HEIGHT ELSE --left upper corner
        "0000";

    vsync_next <= 0 WHEN frame_finished = '1' AND start = '1' ELSE
        vsync_reg + 1 WHEN line_finished = '1' AND start = '1' ELSE
        vsync_reg;

    bram_address_next <= (OTHERS => '0') WHEN vsync_reg = V_MAX_LINE - 1 AND start = '1' ELSE
        bram_address_reg + 1 WHEN hsync_reg < FRAME_WIDTH - 1 AND vsync_reg < FRAME_HEIGHT - 1 AND start = '1'ELSE bram_address_reg;
        
    web <= '1' WHEN hsync_reg < FRAME_WIDTH - 1 AND vsync_reg < FRAME_HEIGHT - 1 and start = '1' else '0';

    PROCESS (pxl_clk)
    BEGIN
        IF rising_edge(pxl_clk) THEN
            hsync_reg <= hsync_next;
            vsync_reg <= vsync_next;
            bram_address_reg <= bram_address_next;
        END IF;
    END PROCESS;
END ARCHITECTURE;