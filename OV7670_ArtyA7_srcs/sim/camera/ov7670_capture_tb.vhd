LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
use ieee.math_real.all;

USE std.textio.ALL;
USE std.env.finish;

ENTITY ov7670_capture_tb IS
END ov7670_capture_tb;

ARCHITECTURE sim OF ov7670_capture_tb IS

    CONSTANT clk_hz : INTEGER := 100e6;
    CONSTANT pclk_hz : INTEGER := 24e6;
    CONSTANT vga_clk_hz : INTEGER := 25e6;
    
    constant C_I_WIDTH : integer  := 160; --160 320 640
    constant C_I_HEIGHT : integer := 120; --120 240 480
    constant C_I_NBITS  : integer := integer(ceil(log2(real( C_I_WIDTH * C_I_HEIGHT + 1))));
    
    constant C_I_WIDTH_T  : integer  := 800; --160 320 640
    constant C_I_HEIGHT_T : integer := 500; --120 240 480

    CONSTANT clk_period : TIME := 1 sec / clk_hz;
    CONSTANT clk_period_pclk : TIME := 1 sec / pclk_hz;
    CONSTANT clk_period_vga_clk : TIME := 1 sec / vga_clk_hz;

    SIGNAL clk, ov7670_pclk, vga_clk : STD_LOGIC := '1';
    SIGNAL rst : STD_LOGIC := '1';
    SIGNAL rst_n : STD_LOGIC := '1';

    SIGNAL config_finished : STD_LOGIC := '0';
    SIGNAL ov7670_vsync : STD_LOGIC := '1';
    SIGNAL ov7670_href : STD_LOGIC := '0';
    SIGNAL ov7670_data : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL ov7670_12data : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');
    SIGNAL start : STD_LOGIC := '0';
    SIGNAL start_href : STD_LOGIC := '0';
    SIGNAL start_pclk : STD_LOGIC := '0';
    SIGNAL frame_finished_o : STD_LOGIC := '0';
    SIGNAL pixel_data : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
    SIGNAL vsync_cnt_o : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL href_cnt_o : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');
    SIGNAL pclk_cnt_o : unsigned(11 DOWNTO 0) := (OTHERS => '0');

    --frame_buffer signals
    SIGNAL wea : STD_LOGIC_VECTOR(0 DOWNTO 0) := (OTHERS => '0');
    SIGNAL dina : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');
    SIGNAL addra : STD_LOGIC_VECTOR(18 -4 DOWNTO 0) := (OTHERS => '0');

    SIGNAL pclk_cnt_reg, pclk_cnt_next : INTEGER RANGE 0 TO 640 * 2 := 0;
    SIGNAL href_reg, href_next : INTEGER RANGE 0 TO 480 := 0;
    --vga signals
    SIGNAL vga_hsync : STD_LOGIC := '0';
    SIGNAL vga_vsync : STD_LOGIC := '0';
    SIGNAL vga_red : STD_LOGIC_VECTOR (3 DOWNTO 0) := (OTHERS => '0');
    SIGNAL vga_blue : STD_LOGIC_VECTOR (3 DOWNTO 0) := (OTHERS => '0');
    SIGNAL vga_green : STD_LOGIC_VECTOR (3 DOWNTO 0) := (OTHERS => '0');

    SIGNAL addrb : STD_LOGIC_VECTOR(18 -4 DOWNTO 0) := (OTHERS => '0');
    SIGNAL doutb : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');
    SIGNAL vga_start : STD_LOGIC := '0';
    
        component fifo_generator_0 
  PORT (
    rst : IN STD_LOGIC;
    wr_clk : IN STD_LOGIC;
    rd_clk : IN STD_LOGIC;
    din : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
    wr_en : IN STD_LOGIC;
    rd_en : IN STD_LOGIC;
    dout : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
    full : OUT STD_LOGIC;
    empty : OUT STD_LOGIC;
    almost_full : out std_logic;
    wr_rst_busy : OUT STD_LOGIC;
    rd_rst_busy : OUT STD_LOGIC
  );
END component;

    COMPONENT blk_mem_gen_1 IS
        PORT (
            clka : IN STD_LOGIC;
            ena : IN STD_LOGIC;
            wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
            addra : IN STD_LOGIC_VECTOR(18 -4 DOWNTO 0);
            dina : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
            clkb : IN STD_LOGIC;
            enb : IN STD_LOGIC;
            addrb : IN STD_LOGIC_VECTOR(18 -4 DOWNTO 0);
            doutb : OUT STD_LOGIC_VECTOR(11 DOWNTO 0)
        );
    END COMPONENT;

  signal s_slv_hsync_risingEdge_reg      : std_logic_vector(32 -1 downto 0);
  signal s_slv_pixel_risingEdge_reg      : std_logic_vector(32 -1 downto 0);
  
  signal s_slv_hsync_risingEdge2_reg      : std_logic_vector(32 -1 downto 0);
  signal s_slv_pixel_risingEdge2_reg      : std_logic_vector(32 -1 downto 0);

    -- OV7670-like timing (datasheet: 656x488 total, 640x480 active)
  constant PCLK_PERIOD : time := 41.666 ns; -- ~24 MHz

  constant H_ACTIVE : integer := 640;
  constant H_BLANK  : integer := 656 - H_ACTIVE; -- 16
  constant H_TOTAL  : integer := H_ACTIVE + H_BLANK;

  constant V_ACTIVE : integer := 480;
  constant V_BLANK  : integer := 488 - V_ACTIVE; -- 8
  constant V_TOTAL  : integer := V_ACTIVE + V_BLANK;

  -- Signals
  signal pclk  : std_logic := '0';
  signal href  : std_logic := '0';
  signal vsync : std_logic := '0';
  signal data  : std_logic_vector(7 downto 0) := (others => '0');

  -- Simple RGB565 pattern generator
  function rgb565_hi(px : integer; ln : integer) return std_logic_vector is
    -- Make some bands from coordinates
    variable r5 : unsigned(4 downto 0) := to_unsigned((px/40) mod 32, 5);
    variable g6 : unsigned(5 downto 0) := to_unsigned((ln/8)  mod 64, 6);
    variable b5 : unsigned(4 downto 0) := to_unsigned((px/20) mod 32, 5);
    variable word16 : unsigned(15 downto 0);
    begin
    word16 := r5 & g6(5 downto 3) & g6(2 downto 0) & b5; -- pack later, just hi here
    return std_logic_vector(word16(15 downto 8));
  end;

   function rgb565_lo(px : integer; ln : integer) return std_logic_vector is
    variable r5 : unsigned(4 downto 0) := to_unsigned((px/40) mod 32, 5);
    variable g6 : unsigned(5 downto 0) := to_unsigned((ln/8)  mod 64, 6);
    variable b5 : unsigned(4 downto 0) := to_unsigned((px/20) mod 32, 5);
    variable word16 : unsigned(15 downto 0);
  begin
    word16 := r5 & g6(5 downto 0) & b5;
    return std_logic_vector(word16(7 downto 0));
  end;
  
  signal s_sl_h_sync   : std_logic;-- => ,--: OUT  STD_LOGIC;  --horiztonal sync pulse
signal s_sl_v_sync   : std_logic;-- => ,--: OUT  STD_LOGIC;  --vertical sync pulse
signal s_sl_disp_ena : std_logic;-- => ,--: OUT  STD_LOGIC;  --display enable ('1' = display time, '0
signal s_i_column   : integer;-- => ,--: OUT  INTEGER;    --horizontal pixel coordinate
signal s_i_row      : integer;-- => ,--: OUT  INTEGER;    --vertical pixel coordinate
signal s_sl_n_blank  : std_logic;-- => ,--: OUT  STD_LOGIC;  --direct blacking output to DAC
signal s_sl_n_sync   : std_logic;-- => );--: OUT  STD_LOGIC); --sync-on-green output to DAC

signal full        : std_logic;
signal empty       : std_logic;
signal almost_full : std_logic;
signal wr_rst_busy : std_logic;
signal rd_rst_busy : std_logic;

signal s_slv_tpg_VGA_R    :  std_logic_vector(3 downto 0);
signal s_slv_tpg_VGA_B    :  std_logic_vector(3 downto 0);
signal s_slv_tpg_VGA_G    :  std_logic_vector(3 downto 0);
signal s_sl_tpg_VGA_HS_O :  std_logic;  
signal s_sl_tpg_VGA_VS_O :  std_logic; 

signal s_slv_tpg_VGA_gen_R    :  std_logic_vector(3 downto 0);
signal s_slv_tpg_VGA_gen_B    :  std_logic_vector(3 downto 0);
signal s_slv_tpg_VGA_gen_G    :  std_logic_vector(3 downto 0); 

BEGIN

  -- PCLK ~24 MHz
  pclk_proc : process
  begin
    pclk <= not pclk;
    wait for PCLK_PERIOD/2;
  end process;

   -- Frame generator: VSYNC pulse, then V_TOTAL lines; HREF during active pixels only
  stim_proc : process
  begin
    wait for 10*PCLK_PERIOD;

    -- Repeat a few frames
    for frame in 0 to 2 loop
      -- VSYNC: short active-high pulse at frame start (a few PCLKs)
      vsync <= '1';
      wait for PCLK_PERIOD*8;
      vsync <= '0';

      for v in 0 to V_TOTAL-1 loop
        if v < V_ACTIVE then
          -- Active line: HREF high during active pixel bytes (RGB565 -> 2 bytes per pixel)
          href <= '1';
          for x in 0 to H_ACTIVE-1 loop
            -- High byte
            wait until rising_edge(pclk);
            data <= rgb565_hi(x, v);
            -- Low byte
            wait until rising_edge(pclk);
            data <= rgb565_lo(x, v);
          end loop;
          href <= '0';

          -- Horizontal blank: consume remaining clocks up to H_TOTAL
          -- We already spent 2*H_ACTIVE PCLKs for pixel bytes; OV7670 only drives PCLK when valid,
          -- but many capture blocks assume a steady PCLK. We'll idle for H_BLANK "byte slots".
          for i in 0 to (H_BLANK*2)-1 loop
            wait until rising_edge(pclk);
            data <= (others => '0');
          end loop;

        else
          -- Vertical blanking lines: no HREF, just idle for a full line's worth
          for i in 0 to (H_TOTAL*2)-1 loop
            wait until rising_edge(pclk);
            data <= (others => '0');
          end loop;
        end if;
      end loop;

      -- small gap between frames
      for i in 0 to 200 loop
        wait until rising_edge(pclk);
      end loop;
    end loop;

    wait; -- stop
  end process;


    rst_n  <= not(rst);
    clk <= NOT clk AFTER clk_period / 2;
    ov7670_pclk <= NOT ov7670_pclk AFTER clk_period_pclk / 2;
    vga_clk <= NOT vga_clk AFTER clk_period_vga_clk / 2;

    PROCESS (ov7670_pclk)
    BEGIN
        IF rising_edge(ov7670_pclk) THEN
            ov7670_data <= STD_LOGIC_VECTOR(unsigned(ov7670_data) + 1);
        END IF;
    END PROCESS;
    
    ov7670_12data <= "0000" & ov7670_data;
    
         fifo_generator : fifo_generator_0
PORT map(
    rst         => rst,
    wr_clk      => ov7670_pclk,
    rd_clk      => ov7670_pclk,
    
    din         => ov7670_12data, 
    wr_en       => ov7670_href,
    
    rd_en       => s_sl_disp_ena,
    dout        => doutb,
    
    full        => full,
    empty       => empty,
    almost_full => almost_full,
    wr_rst_busy => wr_rst_busy,
    rd_rst_busy => rd_rst_busy
  );

--    frame_buffer : blk_mem_gen_1
--    PORT MAP(
--        clka => ov7670_pclk, --clk,
--        wea => ov7670_href, --wea,
--        ena => '1',
--        addra => addra,
--        dina => dina,
--        clkb => vga_clk,
--        enb => '1',
--        addrb => addrb,
--        doutb => doutb
--    );

    frameCheck_inst: entity work.frameCheck
     generic map(
        GI_REG_WIDTH => 32
    )
     port map(
        i_sl_clk                   => clk,
        i_sl_rst                   => rst,
        i_sl_pclk                  => pclk,
        i_sl_vsync                 => vsync,
        i_sl_hsync                 => href,
        o_slv_hsync_risingEdge_reg => s_slv_hsync_risingEdge_reg,
        o_slv_pixel_risingEdge_reg => s_slv_pixel_risingEdge_reg
    );
    
    frameCheck_inst2: entity work.frameCheck
     generic map(
        GI_REG_WIDTH => 32
    )
     port map(
        i_sl_clk                   => clk,
        i_sl_rst                   => rst,
        i_sl_pclk                  => ov7670_pclk,
        i_sl_vsync                 => ov7670_vsync,
        i_sl_hsync                 => ov7670_href,
        o_slv_hsync_risingEdge_reg => s_slv_hsync_risingEdge2_reg,
        o_slv_pixel_risingEdge_reg => s_slv_pixel_risingEdge2_reg
    );



    DUT : ENTITY work.ov7670_capture(rtl)
        PORT MAP(
            clk => clk,
            rst => rst,
            config_finished => '1',
            ov7670_vsync => ov7670_vsync,
            ov7670_href =>  ov7670_href,
            ov7670_pclk =>  ov7670_pclk,
            ov7670_data =>  ov7670_data,
            start => start,
            --start_href => '0',
            --start_pclk => '0',
            frame_finished_o => frame_finished_o,
            pixel_data => pixel_data,
            --vsync_cnt_o => OPEN,
            wea => wea,
            dina => dina,
            addra => addra
        );

    vga : ENTITY work.vga_controller(rtl)
        PORT MAP(
            --clk => clk,
            rst => rst,
            pxl_clk => vga_clk,
            VGA_HS_O => vga_hsync,
            VGA_VS_O => vga_vsync,
            VGA_R => vga_red,
            VGA_B => vga_blue,
            VGA_G => vga_green,
            start => vga_start,
            addrb => addrb,
            doutb => doutb
        );
        
  vga_controller_gen : entity work.vga_controller_gen(behavior)
  GENERIC map(
    h_pulse   => 96, --: INTEGER := 208;    --horiztonal sync pulse width in pixels
    h_bp      => C_I_WIDTH_T -(C_I_WIDTH + 96 + 16), --: INTEGER := 336;    --horiztonal back po
    h_pixels  => C_I_WIDTH, --: INTEGER := 1920;   --horiztonal display width in pixels
    h_fp      => 16, --: INTEGER := 128;    --horiztonal front porch width in pixels
    h_pol     => '1', --: STD_LOGIC := '0';  --horizontal sync pulse polarity (1 = positive, 0 = n
    v_pulse   => 2, --: INTEGER := 3;      --vertical sync pulse width in rows
    v_bp      => C_I_HEIGHT_T -(C_I_HEIGHT +2 + 10 +1), --: INTEGER := 38;     --vertical back p
    v_pixels  => C_I_HEIGHT, --: INTEGER := 1200;   --vertical display width in rows
    v_fp      => 10, --: INTEGER := 1;      --vertical front porch width in rows
    v_pol     => '1' )--: STD_LOGIC := '1'); --vertical sync pulse polarity (1 = positive, 0 = neg
  PORT map(
    pixel_clk => vga_clk, --pxl_clk,--: IN   STD_LOGIC;  --pixel clock at frequency of VGA mode being used
    reset_n   => rst_n,--: IN   STD_LOGIC;  --active low asycnchronous reset

    h_sync    => s_sl_h_sync  ,--: OUT  STD_LOGIC;  --horiztonal sync pulse
    v_sync    => s_sl_v_sync  ,--: OUT  STD_LOGIC;  --vertical sync pulse
    disp_ena  => s_sl_disp_ena,--: OUT  STD_LOGIC;  --display enable ('1' = display time, '0' = 
    column    => s_i_column   ,--: OUT  INTEGER;    --horizontal pixel coordinate
    row       => s_i_row      ,--: OUT  INTEGER;    --vertical pixel coordinate
    n_blank   => s_sl_n_blank ,--: OUT  STD_LOGIC;  --direct blacking output to DAC
    n_sync    => s_sl_n_sync  );--: OUT  STD_LOGIC); --sync-on-green output to DAC
    
    s_slv_tpg_VGA_gen_R <= std_logic_vector(to_unsigned(s_i_column+s_i_row , 4));
s_slv_tpg_VGA_gen_G <= std_logic_vector(to_unsigned(s_i_column+s_i_row, 4));
s_slv_tpg_VGA_gen_B <= std_logic_vector(to_unsigned(s_i_column+s_i_row, 4));
    
      vga_tpg_u : entity work.tpg_vga(rtl)
  generic map(
     G_I_WIDTH_TOTAL  => C_I_WIDTH_T,
     G_I_HEIGHT_TOTAL => C_I_HEIGHT_T  
 )
 port map(
 i_sl_clk      => vga_clk,
 o_sl_vga_hs   => s_sl_tpg_VGA_HS_O,
 o_sl_vga_vs   => s_sl_tpg_VGA_VS_O,
 o_slv_vga_r => s_slv_tpg_VGA_R,
 o_slv_vga_g => s_slv_tpg_VGA_G,
 o_slv_vga_b => s_slv_tpg_VGA_B
 );

    SEQUENCER_PROC : PROCESS
    BEGIN
        WAIT FOR clk_period * 2;

        rst <= '0';
        vga_start <= '0';
        start <= '1';
        WAIT FOR clk_period * 10;
        start <= '0';

        ov7670_vsync <= '0'; --start new frame

        WAIT FOR clk_period * 10;
        FOR i IN 1 TO C_I_HEIGHT LOOP --count lines
            ov7670_href <= '1'; --start new line;

            FOR ii IN 1 TO C_I_WIDTH * 2 LOOP --send on line
                WAIT ON ov7670_pclk UNTIL rising_edge(ov7670_pclk);
            END LOOP;

            ov7670_href <= '0'; --end of line;
            WAIT FOR clk_period * 10;
        END LOOP;
        ov7670_vsync <= '1'; --end of frame
        WAIT FOR clk_period * 100;
        vga_start <= '1';

        WAIT ON ov7670_vsync UNTIL ov7670_vsync = '0';
        --finish;
    END PROCESS;

END ARCHITECTURE;