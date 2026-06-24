module axis_sg_mixmux16_v1 // renamed from axis_sg_mixmux8 to reflect new version with 16 tones
	( 
		// AXI Slave I/F for configuration.
		s_axi_aclk		,
		s_axi_aresetn	,

		s_axi_awaddr	,
		s_axi_awprot	,
		s_axi_awvalid	,
		s_axi_awready	,

		s_axi_wdata		,
		s_axi_wstrb		,
		s_axi_wvalid	,
		s_axi_wready	,

		s_axi_bresp		,
		s_axi_bvalid	,
		s_axi_bready	,

		s_axi_araddr	,
		s_axi_arprot	,
		s_axi_arvalid	,
		s_axi_arready	,

		s_axi_rdata		,
		s_axi_rresp		,
		s_axi_rvalid	,
		s_axi_rready	,

		// s_* and m_* reset/clock.
		aclk			,
		aresetn			,

    	// S_AXIS to queue waveforms.
		s_axis_tready	,
		s_axis_tvalid	,
		s_axis_tdata	,

		// AXIS Master for output.
		m_axis_tready	,
		m_axis_tvalid	,
		m_axis_tdata
	);

/**************/
/* Parameters */
/**************/
// Number of parallel dds blocks.
parameter [31:0] N_DDS = 1; // was 2

/*********/
/* Ports */
/*********/
input					s_axi_aclk;
input					s_axi_aresetn;

input	[7:0]			s_axi_awaddr;
input	[2:0]			s_axi_awprot;
input					s_axi_awvalid;
output					s_axi_awready;

input	[31:0]			s_axi_wdata;
input	[3:0]			s_axi_wstrb;
input					s_axi_wvalid;
output					s_axi_wready;

output	[1:0]			s_axi_bresp;
output					s_axi_bvalid;
input					s_axi_bready;

input	[7:0]			s_axi_araddr;
input	[2:0]			s_axi_arprot;
input					s_axi_arvalid;
output					s_axi_arready;

output	[31:0]			s_axi_rdata;
output	[1:0]			s_axi_rresp;
output					s_axi_rvalid;
input					s_axi_rready;

input					aresetn;
input					aclk;

output					s_axis_tready;
input					s_axis_tvalid;
input 	[47:0]			s_axis_tdata; // changed from 32 bits to 48 bits to accommodate 16 tones

input					m_axis_tready;
output					m_axis_tvalid;
output	[N_DDS*32-1:0]	m_axis_tdata;

/********************/
/* Internal signals */
/********************/
// Registers.
wire [31:0] PINC0_REG;
wire [31:0] PINC1_REG;
wire [31:0] PINC2_REG;
wire [31:0] PINC3_REG;
wire [31:0] PINC4_REG;
wire [31:0] PINC5_REG;
wire [31:0] PINC6_REG;
wire [31:0] PINC7_REG;
wire [31:0] PINC8_REG; // added next 8 regs
wire [31:0] PINC9_REG;
wire [31:0] PINC10_REG;
wire [31:0] PINC11_REG;
wire [31:0] PINC12_REG;
wire [31:0] PINC13_REG;
wire [31:0] PINC14_REG;
wire [31:0] PINC15_REG;

wire [31:0] POFF0_REG;
wire [31:0] POFF1_REG;
wire [31:0] POFF2_REG;
wire [31:0] POFF3_REG;
wire [31:0] POFF4_REG;
wire [31:0] POFF5_REG;
wire [31:0] POFF6_REG;
wire [31:0] POFF7_REG;
wire [31:0] POFF8_REG; // added next 8 regs
wire [31:0] POFF9_REG;
wire [31:0] POFF10_REG;
wire [31:0] POFF11_REG;
wire [31:0] POFF12_REG;
wire [31:0] POFF13_REG;
wire [31:0] POFF14_REG;
wire [31:0] POFF15_REG;

wire [15:0] GAIN0_REG;
wire [15:0] GAIN1_REG;
wire [15:0] GAIN2_REG;
wire [15:0] GAIN3_REG;
wire [15:0] GAIN4_REG;
wire [15:0] GAIN5_REG;
wire [15:0] GAIN6_REG;
wire [15:0] GAIN7_REG;
wire [15:0] GAIN8_REG; // added next 8 regs
wire [15:0] GAIN9_REG;
wire [15:0] GAIN10_REG;
wire [15:0] GAIN11_REG;
wire [15:0] GAIN12_REG;
wire [15:0] GAIN13_REG;
wire [15:0] GAIN14_REG;
wire [15:0] GAIN15_REG;

wire 		WE_REG;

/**********************/
/* Begin Architecture */
/**********************/
// AXI Slave.
axi_slv axi_slv_i
	(
		.s_axi_aclk		(s_axi_aclk	 	),
		.s_axi_aresetn	(s_axi_aresetn	),

		// Write Address Channel.
		.s_axi_awaddr	(s_axi_awaddr 	),
		.s_axi_awprot	(s_axi_awprot 	),
		.s_axi_awvalid	(s_axi_awvalid	),
		.s_axi_awready	(s_axi_awready	),

		// Write Data Channel.
		.s_axi_wdata	(s_axi_wdata	),
		.s_axi_wstrb	(s_axi_wstrb	),
		.s_axi_wvalid	(s_axi_wvalid   ),
		.s_axi_wready	(s_axi_wready	),

		// Write Response Channel.
		.s_axi_bresp	(s_axi_bresp	),
		.s_axi_bvalid	(s_axi_bvalid	),
		.s_axi_bready	(s_axi_bready	),

		// Read Address Channel.
		.s_axi_araddr	(s_axi_araddr 	),
		.s_axi_arprot	(s_axi_arprot 	),
		.s_axi_arvalid	(s_axi_arvalid	),
		.s_axi_arready	(s_axi_arready	),

		// Read Data Channel.
		.s_axi_rdata	(s_axi_rdata	),
		.s_axi_rresp	(s_axi_rresp	),
		.s_axi_rvalid	(s_axi_rvalid	),
		.s_axi_rready	(s_axi_rready	),

		// Registers.
		.PINC0_REG		(PINC0_REG		),
		.PINC1_REG		(PINC1_REG		),
		.PINC2_REG		(PINC2_REG		),
		.PINC3_REG		(PINC3_REG		),
		.PINC4_REG		(PINC4_REG		),
		.PINC5_REG		(PINC5_REG		),
		.PINC6_REG		(PINC6_REG		),
		.PINC7_REG		(PINC7_REG		),
		.PINC8_REG		(PINC8_REG		), // added next 8 registers
		.PINC9_REG		(PINC9_REG		),
		.PINC10_REG		(PINC10_REG		),
		.PINC11_REG		(PINC11_REG		),
		.PINC12_REG		(PINC12_REG		),
		.PINC13_REG		(PINC13_REG		),
		.PINC14_REG		(PINC14_REG		),
		.PINC15_REG		(PINC15_REG		),

		
		.POFF0_REG		(POFF0_REG		),
		.POFF1_REG		(POFF1_REG		),
		.POFF2_REG		(POFF2_REG		),
		.POFF3_REG		(POFF3_REG		),
		.POFF4_REG		(POFF4_REG		),
		.POFF5_REG		(POFF5_REG		),
		.POFF6_REG		(POFF6_REG		),
		.POFF7_REG		(POFF7_REG		),
		.POFF8_REG		(POFF8_REG		), // added next 8 regs
		.POFF9_REG		(POFF9_REG		),
		.POFF10_REG		(POFF10_REG		),
		.POFF11_REG		(POFF11_REG		),
		.POFF12_REG		(POFF12_REG		),
		.POFF13_REG		(POFF13_REG		),
		.POFF14_REG		(POFF14_REG		),
		.POFF15_REG		(POFF15_REG		),


		.GAIN0_REG		(GAIN0_REG		),
		.GAIN1_REG		(GAIN1_REG		),
		.GAIN2_REG		(GAIN2_REG		),
		.GAIN3_REG		(GAIN3_REG		),
		.GAIN4_REG		(GAIN4_REG		),
		.GAIN5_REG		(GAIN5_REG		),
		.GAIN6_REG		(GAIN6_REG		),
		.GAIN7_REG		(GAIN7_REG		),
		.GAIN8_REG		(GAIN8_REG		), // added next 8 regs
		.GAIN9_REG		(GAIN9_REG		),
		.GAIN10_REG		(GAIN10_REG		),
		.GAIN11_REG		(GAIN11_REG		),
		.GAIN12_REG		(GAIN12_REG		),
		.GAIN13_REG		(GAIN13_REG		),
		.GAIN14_REG		(GAIN14_REG		),
		.GAIN15_REG		(GAIN15_REG		),

		.WE_REG			(WE_REG			)
	);

sg_mux16
	#(
		.N_DDS	(N_DDS	)
	)
	sg_mux16_i
	(
		// Reset and clock.
    	.aresetn			(aresetn		),
		.aclk				(aclk			),

    	// S_AXIS to queue waveforms.
		.s_axis_tready_o	(s_axis_tready	),
		.s_axis_tvalid_i	(s_axis_tvalid	),
		.s_axis_tdata_i		(s_axis_tdata 	),

		// M_AXIS for output.
		.m_axis_tready_i	(m_axis_tready	),
		.m_axis_tvalid_o	(m_axis_tvalid	),
		.m_axis_tdata_o		(m_axis_tdata	),

		// Registers.
		.PINC0_REG		(PINC0_REG		),
		.PINC1_REG		(PINC1_REG		),
		.PINC2_REG		(PINC2_REG		),
		.PINC3_REG		(PINC3_REG		),
		.PINC4_REG		(PINC4_REG		),
		.PINC5_REG		(PINC5_REG		),
		.PINC6_REG		(PINC6_REG		),
		.PINC7_REG		(PINC7_REG		),
		.PINC8_REG		(PINC8_REG		), // added next 8 registers
		.PINC9_REG		(PINC9_REG		),
		.PINC10_REG		(PINC10_REG		),
		.PINC11_REG		(PINC11_REG		),
		.PINC12_REG		(PINC12_REG		),
		.PINC13_REG		(PINC13_REG		),
		.PINC14_REG		(PINC14_REG		),
		.PINC15_REG		(PINC15_REG		),

		
		.POFF0_REG		(POFF0_REG		),
		.POFF1_REG		(POFF1_REG		),
		.POFF2_REG		(POFF2_REG		),
		.POFF3_REG		(POFF3_REG		),
		.POFF4_REG		(POFF4_REG		),
		.POFF5_REG		(POFF5_REG		),
		.POFF6_REG		(POFF6_REG		),
		.POFF7_REG		(POFF7_REG		),
		.POFF8_REG		(POFF8_REG		), // added next 8 regs
		.POFF9_REG		(POFF9_REG		),
		.POFF10_REG		(POFF10_REG		),
		.POFF11_REG		(POFF11_REG		),
		.POFF12_REG		(POFF12_REG		),
		.POFF13_REG		(POFF13_REG		),
		.POFF14_REG		(POFF14_REG		),
		.POFF15_REG		(POFF15_REG		),


		.GAIN0_REG		(GAIN0_REG		),
		.GAIN1_REG		(GAIN1_REG		),
		.GAIN2_REG		(GAIN2_REG		),
		.GAIN3_REG		(GAIN3_REG		),
		.GAIN4_REG		(GAIN4_REG		),
		.GAIN5_REG		(GAIN5_REG		),
		.GAIN6_REG		(GAIN6_REG		),
		.GAIN7_REG		(GAIN7_REG		),
		.GAIN8_REG		(GAIN8_REG		), // added next 8 regs
		.GAIN9_REG		(GAIN9_REG		),
		.GAIN10_REG		(GAIN10_REG		),
		.GAIN11_REG		(GAIN11_REG		),
		.GAIN12_REG		(GAIN12_REG		),
		.GAIN13_REG		(GAIN13_REG		),
		.GAIN14_REG		(GAIN14_REG		),
		.GAIN15_REG		(GAIN15_REG		),

		.WE_REG				(WE_REG			)
	);

endmodule

