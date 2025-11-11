LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
use ieee.math_real.all;

library UNISIM;
use UNISIM.VComponents.all;

ENTITY top IS
    PORT (
        clk : IN STD_LOGIC;
        uart_txd_in : IN STD_LOGIC;
        scl : INOUT STD_LOGIC;
        sda : INOUT STD_LOGIC;
        ov7670_vsync : IN STD_LOGIC;
        ov7670_href : IN STD_LOGIC;
        ov7670_pclk : IN STD_LOGIC;
        ov7670_xclk : OUT STD_LOGIC;
        ov7670_data : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        ov7670_pwdn : OUT STD_LOGIC;
        ov7670_reset : OUT STD_LOGIC;
        
        uart_rxd_out : OUT STD_LOGIC;
        btn : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        sw : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        led : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        --sseg_o : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
        --sseg_cs_o : OUT STD_LOGIC;
        
        --- OV7670 2
        scl2 : INOUT STD_LOGIC;
        sda2 : INOUT STD_LOGIC;
        
        ov7670_2_data : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        ov7670_2_reset : OUT STD_LOGIC; --  }]; # RESET IO_L5P_T0_D06_14 Sch=ck_io[4]
        ov7670_2_pwdn  : OUT STD_LOGIC; --  }]; # PWDN IO_L14P_T2_SRCC_14 Sch=ck_io[5]
        ov7670_2_pclk  : in std_logic; --}]; #  PCLK IO_L14N_T2_SRCC_14 Sch=ck_io[6]
        ov7670_2_xclk  : OUT STD_LOGIC; --  }]; # XCLK   IO_L15N_T2_DQS_DOUT_CSO_B_14 Sch=ck_io[7]
        ov7670_2_vsync : in std_logic; --} }]; #VSYNC IO_L11P_T1_SRCC_14 Sch=ck_io[8]
        ov7670_2_href : in std_logic; --}
        
        VGA_HS_O : OUT STD_LOGIC;
        VGA_VS_O : OUT STD_LOGIC;
        VGA_R : OUT STD_LOGIC_VECTOR (3 DOWNTO 0);
        VGA_B : OUT STD_LOGIC_VECTOR (3 DOWNTO 0);
        VGA_G : OUT STD_LOGIC_VECTOR (3 DOWNTO 0)
    );
END top;

ARCHITECTURE rtl OF top IS
    --hallo
    SIGNAL rst : STD_LOGIC := '0';
    SIGNAL uart_start, uart_serial, uart_done_tx, uart_active : STD_LOGIC := '0';
    SIGNAL uart_byte_tx : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL edge : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');

    SIGNAL pxl_clk : STD_LOGIC := '0';
    
    signal s_sl_VGA_VS : STD_LOGIC;
    
    constant C_I_WIDTH    : integer  := 640; --160 320 640
    constant C_I_HEIGHT   : integer :=  480; --120 240 480
    constant C_I_WIDTH_T  : integer  := 800; --160 320 640
    constant C_I_HEIGHT_T : integer := 500; --120 240 480
    constant C_I_NBITS    : integer := 15; --integer(ceil(log2(real( C_I_WIDTH * C_I_HEIGHT + 1))));

    COMPONENT clk_generator
        PORT (
            reset : IN STD_LOGIC;
            clk_in1 : IN STD_LOGIC;
            locked : OUT STD_LOGIC;
            o_xclk_ov7670 : OUT STD_LOGIC
        );
    END COMPONENT;

    COMPONENT vga_clk_gen IS
        PORT (
            clk_in1 : IN STD_LOGIC;
            reset : IN STD_LOGIC;
            clk_out1 : OUT STD_LOGIC;
            locked : OUT STD_LOGIC
        );
    END COMPONENT;
    
    COMPONENT blk_mem_gen_1 IS
        PORT (
            clka : IN STD_LOGIC;
            ena : IN STD_LOGIC;
            wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
            addra : IN STD_LOGIC_VECTOR(C_I_NBITS -1 DOWNTO 0); --4
            dina : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
            clkb : IN STD_LOGIC;
            enb : IN STD_LOGIC;
            addrb : IN STD_LOGIC_VECTOR(C_I_NBITS -1 DOWNTO 0); --4
            doutb : OUT STD_LOGIC_VECTOR(11 DOWNTO 0)
        );
    END COMPONENT;
    
    component tpg_vga is
    Port ( i_sl_clk : in STD_LOGIC;
           o_sl_vga_hs : out STD_LOGIC;
           o_sl_vga_vs : out STD_LOGIC;
           o_slv_vga_r : out STD_LOGIC_VECTOR (3 downto 0);
           o_slv_vga_g : out STD_LOGIC_VECTOR (3 downto 0);
           o_slv_vga_b : out STD_LOGIC_VECTOR (3 downto 0));
    end component;
    
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
    
    component ila_0  is
    PORT (
    clk : IN STD_LOGIC;
    probe0 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe1 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe2 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe3 : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
    probe4 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    probe5 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe6 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe7 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe8 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    probe9 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    probe10 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    probe11 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    probe12 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe13 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe14 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe15 : IN STD_LOGIC_VECTOR(11 DOWNTO 0);   
    probe16 : IN STD_LOGIC_VECTOR(31 DOWNTO 0); 
    probe17 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    probe18 : IN STD_LOGIC_VECTOR(31 DOWNTO 0); 
    probe19 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
    probe20 : IN STD_LOGIC_VECTOR(31 DOWNTO 0); 
    probe21 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    probe22 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe23 : IN STD_LOGIC_VECTOR(0 DOWNTO 0)
    );
    END COMPONENT;

    SIGNAL sseg_byte : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL config_finished : STD_LOGIC := '0';

    SIGNAL buf1_vsync, buf2_vsync, buf1_href, buf2_href : STD_LOGIC := '0';
    SIGNAL buf1_pclk, buf2_pclk : STD_LOGIC := '0';
    SIGNAL buf1_data, buf2_data : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');

    SIGNAL vga_640x480_clk : STD_LOGIC := '0';
    SIGNAL xclk_ov7670 : STD_LOGIC := '0';

    SIGNAL pixel_data : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
    SIGNAL ena : STD_LOGIC := '0';
    SIGNAL wea : STD_LOGIC_VECTOR(0 DOWNTO 0) := (OTHERS => '0');
    SIGNAL addra : STD_LOGIC_VECTOR(C_I_NBITS -1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL dina : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');
    SIGNAL enb : STD_LOGIC := '0';
    SIGNAL addrb : STD_LOGIC_VECTOR(C_I_NBITS -1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL doutb : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');
    signal web   : STD_LOGIC_vector(0 downto 0);
    signal s_sl_almost_full : std_logic := '0';
    signal s_sl_start_camera : std_logic := '0';
     signal wait_for_camera : std_logic := '0';
    signal s_slv_start_camera : STD_LOGIC_vector(0 downto 0);

    SIGNAL frame_finished : STD_LOGIC := '0';
    
    signal s_sl_rd_fifo_en : STD_LOGIC_vector(0 downto 0);
    signal s_slv_vga_px8 : std_logic_vector(7 downto 0);
    
    signal  s_slv_ov7670_vsync : STD_LOGIC_vector(0 downto 0); 
    signal  s_slv_ov7670_href : STD_LOGIC_vector(0 downto 0); 
    signal  s_slv_ov7670_pclk :STD_LOGIC_vector(0 downto 0); 
    
    signal  s_slv_ov7670_2_vsync : STD_LOGIC_vector(0 downto 0); 
    signal  s_slv_ov7670_2_href : STD_LOGIC_vector(0 downto 0); 
    signal  s_slv_ov7670_2_pclk :STD_LOGIC_vector(0 downto 0); 
    
    signal s_slv_VGA_R    :  std_logic_vector(3 downto 0);
    signal s_slv_VGA_B    :  std_logic_vector(3 downto 0);
    signal s_slv_VGA_G    :  std_logic_vector(3 downto 0);
    signal s_slv_VGA_HS_O :  std_logic_vector(0 downto 0);  
    signal s_slv_VGA_VS_O :  std_logic_vector(0 downto 0);
    
    signal s_slv_tpg_VGA_gen_R    :  std_logic_vector(3 downto 0);
    signal s_slv_tpg_VGA_gen_B    :  std_logic_vector(3 downto 0);
    signal s_slv_tpg_VGA_gen_G    :  std_logic_vector(3 downto 0); 
    
    signal s_slv_tpg_VGA_R    :  std_logic_vector(3 downto 0);
    signal s_slv_tpg_VGA_B    :  std_logic_vector(3 downto 0);
    signal s_slv_tpg_VGA_G    :  std_logic_vector(3 downto 0);
    signal s_sl_tpg_VGA_HS_O :  std_logic;  
    signal s_sl_tpg_VGA_VS_O :  std_logic; 
    
    signal s_slv_tpg_VGA_HS_O :  std_logic_vector(0 downto 0);   
    signal s_slv_tpg_VGA_VS_O :  std_logic_vector(0 downto 0); 
    
    signal s_slv_fifo_full :  std_logic_vector(0 downto 0); 
    signal s_slv_fifo_empty :  std_logic_vector(0 downto 0); 
    
    signal s_sl_clk24 :  std_logic;  
    signal s_sl_clk25_2 :  std_logic; 
    
    signal s_sl_ov7670_reset : std_logic := '1';
    
    signal s_slv_hsync_risingEdge_reg         : std_logic_vector(32 -1 downto 0);
    signal s_slv_numBytes_risingEdge_reg      : std_logic_vector(32 -1 downto 0);
   
    signal edges_valid        : std_logic_vector(0 downto 0);
    signal edges_10ms         : unsigned(32 -1 downto 0);
    signal pclk_hz           :  unsigned(32 -1 downto 0);

    signal href_counter         :  unsigned(32 -1 downto 0);

    signal s_slv_disp_ena :  std_logic_vector(0 downto 0); 
    
    signal s_slv_v_sync   : std_logic_vector(0 downto 0); 
    signal s_slv_h_sync   : std_logic_vector(0 downto 0); 

    signal s_sl_h_sync   : std_logic;-- => ,--: OUT  STD_LOGIC;  --horiztonal sync pulse
    signal s_sl_v_sync   : std_logic;-- => ,--: OUT  STD_LOGIC;  --vertical sync pulse
    signal s_sl_disp_ena : std_logic;-- => ,--: OUT  STD_LOGIC;  --display enable ('1' = display time, '0' = blanking time)
    signal s_i_column   : integer;-- => ,--: OUT  INTEGER;    --horizontal pixel coordinate
    signal s_i_row      : integer;-- => ,--: OUT  INTEGER;    --vertical pixel coordinate
    signal s_sl_n_blank  : std_logic;-- => ,--: OUT  STD_LOGIC;  --direct blacking output to DAC
    signal s_sl_n_sync   : std_logic;-- => );--: OUT  STD_LOGIC); --sync-on-green output to DAC

    signal sof_pulse     : std_logic := '0';  -- VSYNC rising edge in PCLK domain
    signal vsync_d       : std_logic := '0';
    signal run_display   : std_logic := '0';
    signal vga_reset_n   : std_logic := '0';  -- drives vga_controller_gen.reset_n

    -- From FIFO core (enable this port when generating IP):
    signal rd_data_count : std_logic_vector(11 downto 0); -- e.g., 0..4095 bytes

    type st_t is (WAIT_DEPTH, WAIT_SOF, RUN);
    signal st : st_t := WAIT_DEPTH;
    
    signal fifo_rd_en : std_logic := '0';

    -- choose your threshold: 2 lines = 2*640 = 1280 bytes
    function to_uint(slv: std_logic_vector) return natural is
    begin return to_integer(unsigned(slv)); end;

    ATTRIBUTE MARK_DEBUG : STRING;
    ATTRIBUTE MARK_DEBUG OF s_slv_ov7670_vsync : SIGNAL IS "true";
    ATTRIBUTE MARK_DEBUG OF s_slv_ov7670_href : SIGNAL IS "true";
    ATTRIBUTE MARK_DEBUG OF s_slv_ov7670_pclk : SIGNAL IS "true";
    ATTRIBUTE MARK_DEBUG OF ov7670_data : SIGNAL IS "true";
    ATTRIBUTE MARK_DEBUG OF s_slv_VGA_HS_O : SIGNAL IS "true";
    ATTRIBUTE MARK_DEBUG OF s_slv_VGA_VS_O : SIGNAL IS "true";
    ATTRIBUTE MARK_DEBUG OF s_slv_VGA_R : SIGNAL IS "true";
    ATTRIBUTE MARK_DEBUG OF s_slv_VGA_B : SIGNAL IS "true";
    ATTRIBUTE MARK_DEBUG OF s_slv_VGA_G : SIGNAL IS "true";
    
BEGIN

    --?? metastability of external signals
    PROCESS (pxl_clk)
    BEGIN
        IF rising_edge(pxl_clk) THEN
            buf1_vsync <= ov7670_2_vsync;
            buf2_vsync <= buf1_vsync;

            buf1_href <= ov7670_2_href;
            buf2_href <= buf1_href;

            buf1_pclk <= ov7670_2_pclk;
            buf2_pclk <= buf1_pclk;

            buf1_data <= ov7670_2_data;
            buf2_data <= buf1_data;
        END IF;
    END PROCESS;

    process(buf2_pclk)
    begin
      if rising_edge(buf2_pclk) then
        vsync_d   <= buf2_vsync;
        sof_pulse <= '1' when (vsync_d='0' and buf2_vsync='1') else '0';
      end if;
    end process;

    process(buf2_pclk)
begin
  if rising_edge(buf2_pclk) then
    if rst = '1' then
      st          <= WAIT_DEPTH;
      run_display <= '0';
      vga_reset_n <= '0';
    else
      case st is
        when WAIT_DEPTH =>
          vga_reset_n <= '0';        -- hold VGA in reset
          run_display <= '0';
          if to_uint(rd_data_count) >= 1280 then
            st <= WAIT_SOF;          -- depth ok, wait for frame boundary
          end if;

        when WAIT_SOF =>
          vga_reset_n <= '0';        -- still hold reset
          run_display <= '0';
          if sof_pulse = '1' then
            vga_reset_n <= '1';      -- release reset **on SOF**
            st          <= RUN;
          end if;

        when RUN =>
          vga_reset_n <= '1';        -- VGA counters run
          run_display <= '1';        -- we can read now
          -- (Optional) if FIFO underflows badly, you can drop back to WAIT_DEPTH
          -- if to_uint(rd_data_count) < 64 then st <= WAIT_DEPTH; end if;
      end case;
    end if;
  end if;
end process;

    
    s_slv_ov7670_vsync(0) <= buf2_vsync;
    s_slv_ov7670_href(0)  <= buf2_href;
    s_slv_ov7670_pclk(0)  <= buf2_pclk;
    
    s_slv_ov7670_2_vsync(0) <= ov7670_2_vsync;
    s_slv_ov7670_2_href(0)  <= ov7670_2_href;
    s_slv_ov7670_2_pclk(0)  <= ov7670_2_pclk;

    rst <= '0';

    ov7670_pwdn <= '0'; -- Power device up
    ov7670_2_pwdn <= '0'; -- Power device up
    
    xclk_pll : clk_generator
    PORT MAP(
        clk_in1 => clk,
        o_xclk_ov7670 => xclk_ov7670,
        reset => '0',
        locked => OPEN
    );

    vga_pll : vga_clk_gen
    PORT MAP
    (-- Clock in ports
        clk_in1 => clk,
        reset => '0',
        locked => OPEN,
        -- Clock out ports
        clk_out1 => pxl_clk
    );

    ov7670_xclk   <= xclk_ov7670;
    ov7670_2_xclk <= xclk_ov7670;

    ov7670_configuration : ENTITY work.ov7670_configuration(Behavioral)
        PORT MAP(
            clk => clk,
            rst => rst,
            sda => sda2,
            edge => edge,
            scl => scl2,
            ov7670_reset => s_sl_ov7670_reset,
            start => edge(0),
            ack_err => OPEN,
            done => uart_start,
            config_finished => config_finished,
            reg_value => uart_byte_tx
        );

        
        
        ov7670_reset <= '1'; --s_sl_ov7670_reset;
        ov7670_2_reset <= '1';
                   
   frameCheck_inst: entity work.frameCheck
     generic map(
        GI_REG_WIDTH => 32
    )
     port map(
        i_sl_clk                   => clk,
        i_sl_rst                   => rst,
        
        i_sl_pclk                  => buf2_pclk,
        i_sl_vsync                 => buf2_vsync,
        i_sl_hsync                 => buf2_href,
        
        o_slv_hsync_risingEdge_reg => s_slv_hsync_risingEdge_reg,
        o_slv_pixel_risingEdge_reg => s_slv_numBytes_risingEdge_reg
    );
    
      
  pclk_meter_inst: entity work.pclk_freq_meter
  generic map ( G_REF_HZ => 100_000_000, G_GATE_MS => 10 )
  port map (
    i_ref_clk  => clk,
    i_rst      => rst,
    i_pclk     => buf2_pclk,
    o_edges    => edges_10ms,
    o_valid    => edges_valid(0),
    o_freq_hz  => pclk_hz
 );

    ov7670_capture : ENTITY work.ov7670_capture(rtl) 
    generic map(
        G_I_WIDTH  => C_I_WIDTH,
        G_I_HEIGHT => C_I_HEIGHT,
        G_I_NBITS  => C_I_NBITS
    )
    PORT MAP(
        clk => clk,
        rst => rst,
        config_finished => config_finished,
        ov7670_vsync => buf2_vsync,
        ov7670_href => buf2_href,
        ov7670_pclk => buf2_pclk,
        ov7670_data => buf2_data,
        frame_finished_o => frame_finished,
        pixel_data => pixel_data,
        start => '1', --edge(3),

        --frame_buffer signals
        wea => wea,
        dina => dina,
        addra => addra
        );

        -- Monitor camera timing signals
process(buf2_pclk)
begin
    if rising_edge(buf2_pclk) then
        if buf2_vsync = '0' then  -- Frame active
            href_counter <= href_counter + 1;
        else
            href_counter <= (others => '0');
        end if;
    end if;
end process;
        

        fifo_generator : fifo_generator_0
 PORT map(
   rst         => rst,
   wr_clk      => buf2_pclk,--clk,
   rd_clk      => pxl_clk,
   din         => "0000"&buf2_data, --dina,
   wr_en       => buf2_href, --wea(0),

   rd_en       => s_sl_disp_ena, --web(0), --s_sl_rd_fifo_en(0),
   dout        => doutb,
   full        => s_slv_fifo_full(0),
   empty       => s_slv_fifo_empty(0),
   almost_full => s_sl_almost_full,
   wr_rst_busy => open,
   rd_rst_busy => open
 );
 
 process(xclk_ov7670, rst)
begin
   if rst = '1' then
     s_sl_start_camera <= '0';
   elsif rising_edge(xclk_ov7670) then
     -- Wait for camera to start a frame
     if buf2_href = '1' and s_sl_start_camera = '0' then
        s_sl_start_camera <= '1';
     end if;
   end if;
end process;
             
 s_slv_start_camera(0) <= s_sl_start_camera;
 
 vga_controller_gen : entity work.vga_controller_gen(behavior)
  GENERIC map(
    h_pulse   => 96, --: INTEGER := 208;    --horiztonal sync pulse width in pixels
    h_bp      => C_I_WIDTH_T -(C_I_WIDTH + 96 + 16), --: INTEGER := 336;    --horiztonal back porch width in pixels
    h_pixels  => C_I_WIDTH, --: INTEGER := 1920;   --horiztonal display width in pixels
    h_fp      => 16, --: INTEGER := 128;    --horiztonal front porch width in pixels
    h_pol     => '1', --: STD_LOGIC := '0';  --horizontal sync pulse polarity (1 = positive, 0 = negative)
    v_pulse   => 2, --: INTEGER := 3;      --vertical sync pulse width in rows
    v_bp      => C_I_HEIGHT_T -(C_I_HEIGHT +2 + 10 +1), --: INTEGER := 38;     --vertical back porch width in rows
    v_pixels  => C_I_HEIGHT, --: INTEGER := 1200;   --vertical display width in rows
    v_fp      => 10, --: INTEGER := 1;      --vertical front porch width in rows
    v_pol     => '1' )--: STD_LOGIC := '1'); --vertical sync pulse polarity (1 = positive, 0 = negative)
  PORT map(
    pixel_clk => pxl_clk,--: IN   STD_LOGIC;  --pixel clock at frequency of VGA mode being used
    reset_n   => not(rst), --vga_reset_n, --s_sl_start_camera, --not(rst),--: IN   STD_LOGIC;  --active low asycnchronous reset

    h_sync    => s_sl_h_sync  ,--: OUT  STD_LOGIC;  --horiztonal sync pulse
    v_sync    => s_sl_v_sync  ,--: OUT  STD_LOGIC;  --vertical sync pulse
    disp_ena  => s_sl_disp_ena,--: OUT  STD_LOGIC;  --display enable ('1' = display time, '0' = blanking time)
    column    => s_i_column   ,--: OUT  INTEGER;    --horizontal pixel coordinate
    row       => s_i_row      ,--: OUT  INTEGER;    --vertical pixel coordinate
    n_blank   => s_sl_n_blank ,--: OUT  STD_LOGIC;  --direct blacking output to DAC
    n_sync    => s_sl_n_sync  );--: OUT  STD_LOGIC); --sync-on-green output to DAC

    -- Read only when displaying and running and not empty
    fifo_rd_en <= '1' when (s_sl_disp_ena='1' and run_display='1' and s_slv_fifo_empty(0)='0') else '0';

    
     s_slv_h_sync(0) <= s_sl_h_sync;
     s_slv_v_sync(0) <= s_sl_v_sync;

    s_slv_disp_ena(0) <= s_sl_disp_ena;
    
   s_slv_tpg_VGA_gen_R <= std_logic_vector(to_unsigned(s_i_column+s_i_row , 4));
   s_slv_tpg_VGA_gen_G <= std_logic_vector(to_unsigned(s_i_column+s_i_row, 4));
   s_slv_tpg_VGA_gen_B <= std_logic_vector(to_unsigned(s_i_column+s_i_row, 4));
    
    vga_controller : ENTITY work.vga_controller(rtl)
    generic map(
        G_I_WIDTH    => C_I_WIDTH,
        G_I_HEIGHT   => C_I_HEIGHT,
        G_I_NBITS    => C_I_NBITS,
        G_I_WIDTH_T  => C_I_WIDTH_T,
        G_I_HEIGHT_T => C_I_HEIGHT_T
    )
        PORT MAP(
            rst => rst,
            pxl_clk => pxl_clk,
            start => s_sl_start_camera, --sw(0),
            VGA_HS_O => s_slv_VGA_HS_O(0), --VGA_HS_O,
            VGA_VS_O => s_slv_VGA_VS_O(0),
            
            VGA_R => s_slv_VGA_R,
            VGA_G => s_slv_VGA_G,
            VGA_B => s_slv_VGA_B,

            --frame_buffer signals 
            addrb => addrb,
            web   => web(0),
            doutb => doutb --"0000"& s_slv_vga_px8
        );
        
     rate_match_nn_u : entity  work.rate_match_nn(Behavioral)
    Port map ( vga_clk       => pxl_clk,
               rst          => rst,
               vga_active => web(0),
               fifo_empty => s_slv_fifo_empty(0),
               fifo_dout => doutb(7 downto 0),
               fifo_rd_en => s_sl_rd_fifo_en(0),
               vga_px8 => s_slv_vga_px8
    );   
        
     led(1) <= buf2_vsync;
    led(2) <= config_finished;
    led(3) <= frame_finished;

        
     --VGA_HS_O <= s_sl_VGA_VS;
     led(0) <= s_sl_VGA_VS;

    uart_rxd_out <= uart_serial;
    
      
      
     vga_tpg_u : entity work.tpg_vga(rtl)
     generic map(
        G_I_WIDTH_TOTAL  => C_I_WIDTH_T,
        G_I_HEIGHT_TOTAL => C_I_HEIGHT_T
        
    )
    port map(
    i_sl_clk      => pxl_clk,
    o_sl_vga_hs   => s_sl_tpg_VGA_HS_O,
    o_sl_vga_vs   => s_sl_tpg_VGA_VS_O,
    o_slv_vga_r => s_slv_tpg_VGA_R,
    o_slv_vga_g => s_slv_tpg_VGA_G,
    o_slv_vga_b => s_slv_tpg_VGA_B
    );
    
    s_slv_tpg_VGA_HS_O(0) <= s_sl_tpg_VGA_HS_O;
    s_slv_tpg_VGA_VS_O(0) <= s_sl_tpg_VGA_HS_O;

VGA_R <= s_slv_VGA_R               when sw(3 downto 2)="01" else
         s_slv_tpg_VGA_R           when sw(3 downto 2)="00" else
         s_slv_tpg_VGA_gen_R       when sw(3 downto 2)="11" else
         doutb(7 downto 4)         when sw(3 downto 2)="10";
         
VGA_G <= s_slv_VGA_G               when sw(3 downto 2)="01" else
         s_slv_tpg_VGA_G           when sw(3 downto 2)="00" else
         s_slv_tpg_VGA_gen_G       when sw(3 downto 2)="11" else
         doutb(7 downto 4)         when sw(3 downto 2)="10";
         
VGA_B <= s_slv_VGA_B               when sw(3 downto 2)="01" else
         s_slv_tpg_VGA_B           when sw(3 downto 2)="00" else
         s_slv_tpg_VGA_gen_B       when sw(3 downto 2)="11" else
         doutb(7 downto 4)         when sw(3 downto 2)="10";
         
--VGA_G <= s_slv_VGA_B when sw(2)='1' else s_slv_tpg_VGA_B;
--VGA_B <= s_slv_VGA_G when sw(2)='1' else s_slv_tpg_VGA_G;

VGA_VS_O <= s_slv_VGA_VS_O(0)      when sw(3 downto 2)="01" else
            s_sl_tpg_VGA_VS_O      when sw(3 downto 2)="00" else
            s_sl_v_sync            when sw(3 downto 2)="11" else
            s_sl_v_sync            when sw(3 downto 2)="10";
              
VGA_HS_O <= s_slv_VGA_HS_O(0)      when sw(3 downto 2)="01" else
            s_sl_tpg_VGA_HS_O      when sw(3 downto 2)="00" else
            s_sl_h_sync            when sw(3 downto 2)="11" else
            s_sl_h_sync            when sw(3 downto 2)="10";

--buf2_href

--VGA_VS_O <= s_slv_VGA_VS_O(0) when sw(2)='1' else s_sl_tpg_VGA_VS_O;
--VGA_HS_O <= s_slv_VGA_HS_O(0) when sw(2)='1' else s_sl_tpg_VGA_HS_O;

      EDGE_DETECT : ENTITY work.debounce(Behavioral) 
  PORT MAP(
      clk => clk,
      btn => btn,
      edge => edge
      );
  UART_TX : ENTITY work.uart_tx_own(rtl)
      PORT MAP(
          clk => clk,
          rst => rst,
          i_start => uart_start,
          i_byte => uart_byte_tx,
          o_serial => uart_serial,
          o_done => uart_done_tx
      );
    
u_ila :  ila_0
port map(
    clk     => clk,
    probe0  => s_slv_fifo_full, 
    probe1  => s_slv_fifo_empty,
    probe2  => s_slv_disp_ena,
    probe3  => dina,
    probe4  => ov7670_2_data,
    probe5  => wea,
    probe6  => s_slv_v_sync,
    probe7  => s_slv_h_sync,
    probe8  => s_slv_VGA_R,
    probe9  => s_slv_VGA_G,
    probe10 => s_slv_VGA_B,
    probe11 => pixel_data,
    probe12 => s_slv_ov7670_2_vsync,
    probe13 => s_slv_ov7670_2_href,
    probe14 => s_sl_rd_fifo_en,
    probe15 => doutb,
    probe16 => s_slv_hsync_risingEdge_reg,
    probe17 => s_slv_numBytes_risingEdge_reg,
    probe18 => std_logic_vector(edges_10ms) ,
    probe19 => edges_valid,
    probe20 => std_logic_vector(pclk_hz),
    probe21 => s_slv_tpg_VGA_R,
    probe22 => s_slv_tpg_VGA_HS_O,
    probe23 => s_slv_tpg_VGA_VS_O
);

-- --dual port bram
   -- frame_buffer : blk_mem_gen_1
   -- PORT MAP(
   --     clka => clk,
   --     wea => wea,
   --     ena => '1',
   --     addra => addra,
   --     dina => dina,
   --     
   --     clkb => pxl_clk,
   --     enb => '1',
   --     addrb => addrb,
   --     doutb => doutb
   -- );

END ARCHITECTURE;