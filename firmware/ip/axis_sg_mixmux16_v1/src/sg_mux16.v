/*
 * Signal Generator with 16 output waves, independently masked.
 * Waveforms are created using parallel DDSs to cover a larger bandwidth.
 *
 */
module sg_mux16 ( // changed name to reflect new 16 tones
	// Reset and clock.
	aresetn			,
	aclk			,

    // S_AXIS to queue waveforms.
	s_axis_tready_o	,
	s_axis_tvalid_i	,
	s_axis_tdata_i	,

	// M_AXIS for output.
	m_axis_tready_i	,
	m_axis_tvalid_o	,
	m_axis_tdata_o	,	

	// Registers.
	PINC0_REG		,
	PINC1_REG		,
	PINC2_REG		,
	PINC3_REG		,
	PINC4_REG		,
	PINC5_REG		,
	PINC6_REG		,
	PINC7_REG		,
	PINC8_REG		, // added PINC REG 8-15
	PINC9_REG		,
	PINC10_REG		,
	PINC11_REG		,
	PINC12_REG		,
	PINC13_REG		,
	PINC14_REG		,
	PINC15_REG		,

	POFF0_REG		,
	POFF1_REG		,
	POFF2_REG		,
	POFF3_REG		,
	POFF4_REG		,
	POFF5_REG		,
	POFF6_REG		,
	POFF7_REG		,
	POFF8_REG		, // added POFF REG 8-15
	POFF9_REG		,
	POFF10_REG		,
	POFF11_REG		,
	POFF12_REG		,
	POFF13_REG		,
	POFF14_REG		,
	POFF15_REG		,

	GAIN0_REG		,
	GAIN1_REG		,
	GAIN2_REG		,
	GAIN3_REG		,
	GAIN4_REG		,
	GAIN5_REG		,
	GAIN6_REG		,
	GAIN7_REG		,
	GAIN8_REG		, // added GAIN REG 8-15
	GAIN9_REG		,
	GAIN10_REG		,
	GAIN11_REG		,
	GAIN12_REG		,
	GAIN13_REG		,
	GAIN14_REG		,
	GAIN15_REG		,

	WE_REG
	);

/***************/
/* Parameters */
/**************/
// Number of parallel dds blocks.
parameter N_DDS = 1; // before, default 2 and oft. used 4

/*********/
/* Ports */
/*********/
input					aresetn;
input					aclk;

input 	[47:0]			s_axis_tdata_i; // was [39:0] // stopped here
input					s_axis_tvalid_i;
output					s_axis_tready_o;

input					m_axis_tready_i;
output					m_axis_tvalid_o;
output	[N_DDS*32-1:0]	m_axis_tdata_o;

input	[31:0]			PINC0_REG;
input	[31:0]			PINC1_REG;
input	[31:0]			PINC2_REG;
input	[31:0]			PINC3_REG;
input	[31:0]			PINC4_REG;
input	[31:0]			PINC5_REG;
input	[31:0]			PINC6_REG;
input	[31:0]			PINC7_REG;
input	[31:0]			PINC8_REG; // added next 8 PINC inputs
input	[31:0]			PINC9_REG;
input	[31:0]			PINC10_REG;
input	[31:0]			PINC11_REG;
input	[31:0]			PINC12_REG;
input	[31:0]			PINC13_REG;
input	[31:0]			PINC14_REG;
input	[31:0]			PINC15_REG;

input	[31:0]			POFF0_REG;
input	[31:0]			POFF1_REG;
input	[31:0]			POFF2_REG;
input	[31:0]			POFF3_REG;
input	[31:0]			POFF4_REG;
input	[31:0]			POFF5_REG;
input	[31:0]			POFF6_REG;
input	[31:0]			POFF7_REG;
input	[31:0]			POFF8_REG; // added next 8 POFF inputs
input	[31:0]			POFF9_REG;
input	[31:0]			POFF10_REG;
input	[31:0]			POFF11_REG;
input	[31:0]			POFF12_REG;
input	[31:0]			POFF13_REG;
input	[31:0]			POFF14_REG;
input	[31:0]			POFF15_REG;

input	[15:0]			GAIN0_REG;
input	[15:0]			GAIN1_REG;
input	[15:0]			GAIN2_REG;
input	[15:0]			GAIN3_REG;
input	[15:0]			GAIN4_REG;
input	[15:0]			GAIN5_REG;
input	[15:0]			GAIN6_REG;
input	[15:0]			GAIN7_REG;
input	[15:0]			GAIN8_REG; // added next 8 GAIN inputs
input	[15:0]			GAIN9_REG;
input	[15:0]			GAIN10_REG;
input	[15:0]			GAIN11_REG;
input	[15:0]			GAIN12_REG;
input	[15:0]			GAIN13_REG;
input	[15:0]			GAIN14_REG;
input	[15:0]			GAIN15_REG;

input					WE_REG;

/********************/
/* Local Parameters */
/********************/
// Number of output waves.
localparam N_OUT = 16; // changed to 16

/********************/
/* Internal signals */
/********************/
// Fifo.
wire			fifo_wr_en;
wire	[47:0]	fifo_din; // changed to reflect extra 8 bits in mask
wire			fifo_rd_en;
wire	[47:0]	fifo_dout; // changed to reflect extra 8 bits in mask
wire			fifo_full;
wire			fifo_empty;

// PINC/GAIN registers vector.
wire	[31:0]	PINC_REG_v	[0:N_OUT-1];
wire	[31:0]	POFF_REG_v	[0:N_OUT-1];
wire	[15:0]	GAIN_REG_v	[0:N_OUT-1];

// DDS output.
wire 	[N_DDS*32-1:0]	dds_dout	[0:N_OUT-1];
wire	[N_DDS*32-1:0]	dds_dout_la	[0:N_OUT-1];

// Muxed DDS output.
wire	[N_DDS*32-1:0]	dds_mux		[0:N_OUT-1];
wire	[31:0]			dds_mux_v	[0:N_OUT-1][0:N_DDS-1];
wire	[15:0]			dds_real_v	[0:N_OUT-1][0:N_DDS-1];
wire	[15:0]			dds_imag_v	[0:N_OUT-1][0:N_DDS-1];


// Addition vectors.
wire signed [15:0]	add0_real	[0:N_DDS-1];
wire signed [15:0]	add0_imag	[0:N_DDS-1];
wire signed [15:0]	add1_real	[0:N_DDS-1];
wire signed [15:0]	add1_imag	[0:N_DDS-1];
wire signed [15:0]	add2_real	[0:N_DDS-1];
wire signed [15:0]	add2_imag	[0:N_DDS-1];
wire signed [15:0]	add3_real	[0:N_DDS-1];
wire signed [15:0]	add3_imag	[0:N_DDS-1];
wire signed [15:0]	add4_real	[0:N_DDS-1];
wire signed [15:0]	add4_imag	[0:N_DDS-1];
wire signed [15:0]	add5_real	[0:N_DDS-1];
wire signed [15:0]	add5_imag	[0:N_DDS-1];
wire signed [15:0]	add6_real	[0:N_DDS-1];
wire signed [15:0]	add6_imag	[0:N_DDS-1];
wire signed [15:0]	add7_real	[0:N_DDS-1];
wire signed [15:0]	add7_imag	[0:N_DDS-1];
wire signed [15:0]	add8_real	[0:N_DDS-1]; // added addition vectors 8-15
wire signed [15:0]	add8_imag	[0:N_DDS-1];
wire signed [15:0]	add9_real	[0:N_DDS-1];
wire signed [15:0]	add9_imag	[0:N_DDS-1];
wire signed [15:0]	add10_real	[0:N_DDS-1];
wire signed [15:0]	add10_imag	[0:N_DDS-1];
wire signed [15:0]	add11_real	[0:N_DDS-1];
wire signed [15:0]	add11_imag	[0:N_DDS-1];
wire signed [15:0]	add12_real	[0:N_DDS-1];
wire signed [15:0]	add12_imag	[0:N_DDS-1];
wire signed [15:0]	add13_real	[0:N_DDS-1];
wire signed [15:0]	add13_imag	[0:N_DDS-1];
wire signed [15:0]	add14_real	[0:N_DDS-1];
wire signed [15:0]	add14_imag	[0:N_DDS-1];
wire signed [15:0]	add15_real	[0:N_DDS-1];
wire signed [15:0]	add15_imag	[0:N_DDS-1];

reg  signed [19:0]	add0_real_r	[0:N_DDS-1]; // now [19:0], orig [18:0]
reg  signed [19:0]	add0_imag_r	[0:N_DDS-1];
reg  signed [19:0]	add1_real_r	[0:N_DDS-1];
reg  signed [19:0]	add1_imag_r	[0:N_DDS-1];
reg  signed [19:0]	add2_real_r	[0:N_DDS-1];
reg  signed [19:0]	add2_imag_r	[0:N_DDS-1];
reg  signed [19:0]	add3_real_r	[0:N_DDS-1];
reg  signed [19:0]	add3_imag_r	[0:N_DDS-1];
reg  signed [19:0]	add4_real_r	[0:N_DDS-1];
reg  signed [19:0]	add4_imag_r	[0:N_DDS-1];
reg  signed [19:0]	add5_real_r	[0:N_DDS-1];
reg  signed [19:0]	add5_imag_r	[0:N_DDS-1];
reg  signed [19:0]	add6_real_r	[0:N_DDS-1];
reg  signed [19:0]	add6_imag_r	[0:N_DDS-1];
reg  signed [19:0]	add7_real_r	[0:N_DDS-1];
reg  signed [19:0]	add7_imag_r	[0:N_DDS-1];
reg  signed [19:0]	add8_real_r	[0:N_DDS-1];
reg  signed [19:0]	add8_imag_r	[0:N_DDS-1]; // added 8-15 real/imag
reg  signed [19:0]	add9_real_r	[0:N_DDS-1];
reg  signed [19:0]	add9_imag_r	[0:N_DDS-1];
reg  signed [19:0]	add10_real_r 	[0:N_DDS-1];
reg  signed [19:0]	add10_imag_r	[0:N_DDS-1];
reg  signed [19:0]	add11_real_r	[0:N_DDS-1];
reg  signed [19:0]	add11_imag_r	[0:N_DDS-1];
reg  signed [19:0]	add12_real_r	[0:N_DDS-1];
reg  signed [19:0]	add12_imag_r	[0:N_DDS-1];
reg  signed [19:0]	add13_real_r	[0:N_DDS-1];
reg  signed [19:0]	add13_imag_r	[0:N_DDS-1];
reg  signed [19:0]	add14_real_r	[0:N_DDS-1];
reg  signed [19:0]	add14_imag_r	[0:N_DDS-1];
reg  signed [19:0]	add15_real_r	[0:N_DDS-1];
reg  signed [19:0]	add15_imag_r	[0:N_DDS-1];

// Addition results.
wire signed [19:0]	sum0_real	[0:N_DDS-1]; // now [19:0], orig [18:0]
wire signed [19:0]	sum0_imag	[0:N_DDS-1];
wire signed [19:0]	sum1_real	[0:N_DDS-1];
wire signed [19:0]	sum1_imag	[0:N_DDS-1];
wire signed [19:0]	sum2_real	[0:N_DDS-1];
wire signed [19:0]	sum2_imag	[0:N_DDS-1];
wire signed [19:0]	sum3_real	[0:N_DDS-1];
wire signed [19:0]	sum3_imag	[0:N_DDS-1];
wire signed [19:0]	sum4_real	[0:N_DDS-1];
wire signed [19:0]	sum4_imag	[0:N_DDS-1];
wire signed [19:0]	sum5_real	[0:N_DDS-1];
wire signed [19:0]	sum5_imag	[0:N_DDS-1];
wire signed [19:0]	sum6_real	[0:N_DDS-1];
wire signed [19:0]	sum6_imag	[0:N_DDS-1];
wire signed [19:0]	sum7_real	[0:N_DDS-1];
wire signed [19:0]	sum7_imag	[0:N_DDS-1];
wire signed [19:0]	sum8_real	[0:N_DDS-1]; // added 8-14 real/imag
wire signed [19:0]	sum8_imag	[0:N_DDS-1];
wire signed [19:0]	sum9_real	[0:N_DDS-1];
wire signed [19:0]	sum9_imag	[0:N_DDS-1];
wire signed [19:0]	sum10_real	[0:N_DDS-1];
wire signed [19:0]	sum10_imag	[0:N_DDS-1];
wire signed [19:0]	sum11_real	[0:N_DDS-1];
wire signed [19:0]	sum11_imag	[0:N_DDS-1];
wire signed [19:0]	sum12_real	[0:N_DDS-1];
wire signed [19:0]	sum12_imag	[0:N_DDS-1];
wire signed [19:0]	sum13_real	[0:N_DDS-1];
wire signed [19:0]	sum13_imag	[0:N_DDS-1];
wire signed [19:0]	sum14_real	[0:N_DDS-1];
wire signed [19:0]	sum14_imag	[0:N_DDS-1];

reg  signed [19:0]	sum0_real_r	[0:N_DDS-1]; // now [19:0], orig [18:0]
reg  signed [19:0]	sum0_imag_r	[0:N_DDS-1];
reg  signed [19:0]	sum1_real_r	[0:N_DDS-1];
reg  signed [19:0]	sum1_imag_r	[0:N_DDS-1];
reg  signed [19:0]	sum2_real_r	[0:N_DDS-1];
reg  signed [19:0]	sum2_imag_r	[0:N_DDS-1];
reg  signed [19:0]	sum3_real_r	[0:N_DDS-1];
reg  signed [19:0]	sum3_imag_r	[0:N_DDS-1];
reg  signed [19:0]	sum4_real_r	[0:N_DDS-1];
reg  signed [19:0]	sum4_imag_r	[0:N_DDS-1];
reg  signed [19:0]	sum5_real_r	[0:N_DDS-1];
reg  signed [19:0]	sum5_imag_r	[0:N_DDS-1];
reg  signed [19:0]	sum6_real_r	[0:N_DDS-1];
reg  signed [19:0]	sum6_imag_r	[0:N_DDS-1];
reg  signed [19:0]	sum7_real_r	[0:N_DDS-1];
reg  signed [19:0]	sum7_imag_r	[0:N_DDS-1];
reg  signed [19:0]	sum8_real_r	[0:N_DDS-1]; // added 8-14 real/imag
reg  signed [19:0]	sum8_imag_r	[0:N_DDS-1];
reg  signed [19:0]	sum9_real_r	[0:N_DDS-1];
reg  signed [19:0]	sum9_imag_r	[0:N_DDS-1];
reg  signed [19:0]	sum10_real_r	[0:N_DDS-1];
reg  signed [19:0]	sum10_imag_r	[0:N_DDS-1];
reg  signed [19:0]	sum11_real_r	[0:N_DDS-1];
reg  signed [19:0]	sum11_imag_r	[0:N_DDS-1];
reg  signed [19:0]	sum12_real_r	[0:N_DDS-1];
reg  signed [19:0]	sum12_imag_r	[0:N_DDS-1];
reg  signed [19:0]	sum13_real_r	[0:N_DDS-1];
reg  signed [19:0]	sum13_imag_r	[0:N_DDS-1];
reg  signed [19:0]	sum14_real_r	[0:N_DDS-1];
reg  signed [19:0]	sum14_imag_r	[0:N_DDS-1];

// Quantized output.
wire  		[15:0]	dout_real	[0:N_DDS-1];
wire  		[15:0]	dout_imag	[0:N_DDS-1];

// Mask.
wire	[15:0]	mask_int; // changed to 16 bits to accommodate 16 tones

// Output enable.
wire			en_int;
wire			en_int_la;

// Output selection quantization.
// NOTE: change this if N_OUT changes.
wire	[4:0]	qsel; // now 5 bits to accommodate 16 output waves, orig 4 bits for 8 waves
wire	[4:0]	qsel_la;

/**********************/
/* Begin Architecture */
/**********************/
// PINC/POFF/GAIN registers vectors.
assign PINC_REG_v[0] = PINC0_REG;
assign PINC_REG_v[1] = PINC1_REG;
assign PINC_REG_v[2] = PINC2_REG;
assign PINC_REG_v[3] = PINC3_REG;
assign PINC_REG_v[4] = PINC4_REG;
assign PINC_REG_v[5] = PINC5_REG;
assign PINC_REG_v[6] = PINC6_REG;
assign PINC_REG_v[7] = PINC7_REG;
assign PINC_REG_v[8] = PINC8_REG; // added next 8 PINC assigns
assign PINC_REG_v[9] = PINC9_REG;
assign PINC_REG_v[10] = PINC10_REG;
assign PINC_REG_v[11] = PINC11_REG;
assign PINC_REG_v[12] = PINC12_REG;
assign PINC_REG_v[13] = PINC13_REG;
assign PINC_REG_v[14] = PINC14_REG;
assign PINC_REG_v[15] = PINC15_REG;

assign POFF_REG_v[0] = POFF0_REG;
assign POFF_REG_v[1] = POFF1_REG;
assign POFF_REG_v[2] = POFF2_REG;
assign POFF_REG_v[3] = POFF3_REG;
assign POFF_REG_v[4] = POFF4_REG;
assign POFF_REG_v[5] = POFF5_REG;
assign POFF_REG_v[6] = POFF6_REG;
assign POFF_REG_v[7] = POFF7_REG;
assign POFF_REG_v[8] = POFF8_REG; // added next 8 POFF assigns
assign POFF_REG_v[9] = POFF9_REG;
assign POFF_REG_v[10] = POFF10_REG;
assign POFF_REG_v[11] = POFF11_REG;
assign POFF_REG_v[12] = POFF12_REG;
assign POFF_REG_v[13] = POFF13_REG;
assign POFF_REG_v[14] = POFF14_REG;
assign POFF_REG_v[15] = POFF15_REG;

assign GAIN_REG_v[0] = GAIN0_REG;
assign GAIN_REG_v[1] = GAIN1_REG;
assign GAIN_REG_v[2] = GAIN2_REG;
assign GAIN_REG_v[3] = GAIN3_REG;
assign GAIN_REG_v[4] = GAIN4_REG;
assign GAIN_REG_v[5] = GAIN5_REG;
assign GAIN_REG_v[6] = GAIN6_REG;
assign GAIN_REG_v[7] = GAIN7_REG;
assign GAIN_REG_v[8] = GAIN8_REG; // added next 8 GAIN assigns
assign GAIN_REG_v[9] = GAIN9_REG;
assign GAIN_REG_v[10] = GAIN10_REG;
assign GAIN_REG_v[11] = GAIN11_REG;
assign GAIN_REG_v[12] = GAIN12_REG;
assign GAIN_REG_v[13] = GAIN13_REG;
assign GAIN_REG_v[14] = GAIN14_REG;
assign GAIN_REG_v[15] = GAIN15_REG;

// Fifo. 
fifo
    #(
        // Data width.
        .B	(48), // was 40, changed to 48 bits to accomodate 8 more tones in mask
        
        // Fifo depth.
        .N	(16)
    )
    fifo_i
	( 
        .rstn	(aresetn	),
        .clk 	(aclk		),

        // Write I/F.
        .wr_en 	(fifo_wr_en	),
        .din    (fifo_din	),
        
        // Read I/F.
        .rd_en 	(fifo_rd_en	),
        .dout  	(fifo_dout	),
        
        // Flags.
        .full   (fifo_full	),
        .empty  (fifo_empty	)
    );

assign fifo_wr_en	= s_axis_tvalid_i;
assign fifo_din		= s_axis_tdata_i;

generate
genvar i,j;
	// Loop over N_OUT.
	for (i=0; i<N_OUT; i=i+1) begin : GEN_out
		/***********************/
		/* Block instantiation */
		/***********************/
		// DDS.
		dds_top 
			#(
				.N_DDS(N_DDS)
			)
			dds_top_i
			(
				// Reset and clock.
				.rstn			(aresetn		),
				.clk			(aclk			),
		
				// DDS output.
				.dds_dout_o		(dds_dout[i]	),
		
				// Registers.
				.PINC_REG		(PINC_REG_v[i]	),
				.POFF_REG		(POFF_REG_v[i]	),
				.GAIN_REG		(GAIN_REG_v[i]	),
				.WE_REG			(WE_REG			)
			);

		// Latency for dds_dout.
		latency_reg
			#(
				.N(4), // should stay 4
				.B(N_DDS*32)
			)
			dds_dout_latency_reg_i
			(
				.rstn	(aresetn		),
				.clk	(aclk			),
		
				.din	(dds_dout[i]	),
				.dout	(dds_dout_la[i]	)
			);

		/*****************************/
		/* Combinatorial assignments */
		/*****************************/
		// Muxed DDS output.
		assign dds_mux	[i]	= (mask_int[i] == 1'b1)? dds_dout_la[i] : 32'h0000_0000;

		// Loop over N_DDS.
		for (j=0; j<N_DDS; j=j+1) begin : GEN_out_dds
			assign dds_mux_v[i][j]	= dds_mux[i][32*j +: 32];
			assign dds_real_v[i][j]	= dds_mux_v[i][j][15:0];
			assign dds_imag_v[i][j]	= dds_mux_v[i][j][31:16];
		end
	end
endgenerate 

generate
	// Loop over N_DDS.
	for (i=0; i<N_DDS; i=i+1) begin : GEN_add

		// Registers.
		always @(posedge aclk) begin
			// Addition vectors.
			add0_real_r	[i] <= {{4{add0_real[i][15]}},add0_real[i]}; // changed sign-extensions to 4
			add0_imag_r	[i] <= {{4{add0_imag[i][15]}},add0_imag[i]};
			add1_real_r	[i] <= {{4{add1_real[i][15]}},add1_real[i]};
			add1_imag_r	[i] <= {{4{add1_imag[i][15]}},add1_imag[i]};
			add2_real_r	[i] <= {{4{add2_real[i][15]}},add2_real[i]};
			add2_imag_r	[i] <= {{4{add2_imag[i][15]}},add2_imag[i]};
			add3_real_r	[i] <= {{4{add3_real[i][15]}},add3_real[i]};
			add3_imag_r	[i] <= {{4{add3_imag[i][15]}},add3_imag[i]};
			add4_real_r	[i] <= {{4{add4_real[i][15]}},add4_real[i]};
			add4_imag_r	[i] <= {{4{add4_imag[i][15]}},add4_imag[i]};
			add5_real_r	[i] <= {{4{add5_real[i][15]}},add5_real[i]};
			add5_imag_r	[i] <= {{4{add5_imag[i][15]}},add5_imag[i]};
			add6_real_r	[i] <= {{4{add6_real[i][15]}},add6_real[i]};
			add6_imag_r	[i] <= {{4{add6_imag[i][15]}},add6_imag[i]};
			add7_real_r	[i] <= {{4{add7_real[i][15]}},add7_real[i]};
			add7_imag_r	[i] <= {{4{add7_imag[i][15]}},add7_imag[i]};
			add8_real_r	[i] <= {{4{add8_real[i][15]}},add8_real[i]}; // added 8-15 real/imag 
			add8_imag_r	[i] <= {{4{add8_imag[i][15]}},add8_imag[i]};
			add9_real_r	[i] <= {{4{add9_real[i][15]}},add9_real[i]};
			add9_imag_r	[i] <= {{4{add9_imag[i][15]}},add9_imag[i]};
			add10_real_r[i] <= {{4{add10_real[i][15]}},add10_real[i]};
			add10_imag_r[i] <= {{4{add10_imag[i][15]}},add10_imag[i]};
			add11_real_r[i] <= {{4{add11_real[i][15]}},add11_real[i]};
			add11_imag_r[i] <= {{4{add11_imag[i][15]}},add11_imag[i]};
			add12_real_r[i] <= {{4{add12_real[i][15]}},add12_real[i]};
			add12_imag_r[i] <= {{4{add12_imag[i][15]}},add12_imag[i]};
			add13_real_r[i] <= {{4{add13_real[i][15]}},add13_real[i]};
			add13_imag_r[i] <= {{4{add13_imag[i][15]}},add13_imag[i]};
			add14_real_r[i] <= {{4{add14_real[i][15]}},add14_real[i]};
			add14_imag_r[i] <= {{4{add14_imag[i][15]}},add14_imag[i]};
			add15_real_r[i] <= {{4{add15_real[i][15]}},add15_real[i]};
			add15_imag_r[i] <= {{4{add15_imag[i][15]}},add15_imag[i]};

			// Addition results.
			sum0_real_r	[i] <= sum0_real[i];
			sum0_imag_r	[i] <= sum0_imag[i];
			sum1_real_r	[i] <= sum1_real[i];
			sum1_imag_r	[i] <= sum1_imag[i];
			sum2_real_r	[i] <= sum2_real[i];
			sum2_imag_r	[i] <= sum2_imag[i];
			sum3_real_r	[i] <= sum3_real[i];
			sum3_imag_r	[i] <= sum3_imag[i];
			sum4_real_r	[i] <= sum4_real[i];
			sum4_imag_r	[i] <= sum4_imag[i];
			sum5_real_r	[i] <= sum5_real[i];
			sum5_imag_r	[i] <= sum5_imag[i];
			sum6_real_r	[i] <= sum6_real[i];
			sum6_imag_r	[i] <= sum6_imag[i];
			sum7_real_r	[i] <= sum7_real[i]; // added sums 7-14 real / imag
			sum7_imag_r	[i] <= sum7_imag[i];
			sum8_real_r	[i] <= sum8_real[i];
			sum8_imag_r	[i] <= sum8_imag[i];
			sum9_real_r	[i] <= sum9_real[i];
			sum9_imag_r	[i] <= sum9_imag[i];
			sum10_real_r[i] <= sum10_real[i];
			sum10_imag_r[i] <= sum10_imag[i];
			sum11_real_r[i] <= sum11_real[i];
			sum11_imag_r[i] <= sum11_imag[i];
			sum12_real_r[i] <= sum12_real[i];
			sum12_imag_r[i] <= sum12_imag[i];
			sum13_real_r[i] <= sum13_real[i];
			sum13_imag_r[i] <= sum13_imag[i];
			sum14_real_r[i] <= sum14_real[i];
			sum14_imag_r[i] <= sum14_imag[i];
		end

		/*****************************/
		/* Combinatorial assignments */
		/*****************************/
		// Addition vectors.
		assign add0_real[i] = dds_real_v[0][i];
		assign add0_imag[i] = dds_imag_v[0][i];
		assign add1_real[i] = dds_real_v[1][i];
		assign add1_imag[i] = dds_imag_v[1][i];
		assign add2_real[i] = dds_real_v[2][i];
		assign add2_imag[i] = dds_imag_v[2][i];
		assign add3_real[i] = dds_real_v[3][i];
		assign add3_imag[i] = dds_imag_v[3][i];
		assign add4_real[i] = dds_real_v[4][i];
		assign add4_imag[i] = dds_imag_v[4][i];
		assign add5_real[i] = dds_real_v[5][i];
		assign add5_imag[i] = dds_imag_v[5][i];
		assign add6_real[i] = dds_real_v[6][i];
		assign add6_imag[i] = dds_imag_v[6][i];
		assign add7_real[i] = dds_real_v[7][i];
		assign add7_imag[i] = dds_imag_v[7][i];
		assign add8_real[i] = dds_real_v[8][i]; // added addition vec. assignments 8-15 real / imag
		assign add8_imag[i] = dds_imag_v[8][i];
		assign add9_real[i] = dds_real_v[9][i];
		assign add9_imag[i] = dds_imag_v[9][i];
		assign add10_real[i] = dds_real_v[10][i];
		assign add10_imag[i] = dds_imag_v[10][i];
		assign add11_real[i] = dds_real_v[11][i];
		assign add11_imag[i] = dds_imag_v[11][i];
		assign add12_real[i] = dds_real_v[12][i];
		assign add12_imag[i] = dds_imag_v[12][i];
		assign add13_real[i] = dds_real_v[13][i];
		assign add13_imag[i] = dds_imag_v[13][i];
		assign add14_real[i] = dds_real_v[14][i];
		assign add14_imag[i] = dds_imag_v[14][i];
		assign add15_real[i] = dds_real_v[15][i];
		assign add15_imag[i] = dds_imag_v[15][i];

		// Addition results.
		// Added another level of addition
		// LEVEL 1: Add 16 inputs into 8 sums.
		assign sum0_real[i]	= add0_real_r[i] + add1_real_r[i];
		assign sum0_imag[i]	= add0_imag_r[i] + add1_imag_r[i];
		assign sum1_real[i]	= add2_real_r[i] + add3_real_r[i];
		assign sum1_imag[i]	= add2_imag_r[i] + add3_imag_r[i];
		assign sum2_real[i]	= add4_real_r[i] + add5_real_r[i];
		assign sum2_imag[i]	= add4_imag_r[i] + add5_imag_r[i];
		assign sum3_real[i]	= add6_real_r[i] + add7_real_r[i];
		assign sum3_imag[i]	= add6_imag_r[i] + add7_imag_r[i];
		assign sum4_real[i]	= add8_real_r[i] + add9_real_r[i];
		assign sum4_imag[i]	= add8_imag_r[i] + add9_imag_r[i];
		assign sum5_real[i]	= add10_real_r[i] + add11_real_r[i];
		assign sum5_imag[i]	= add10_imag_r[i] + add11_imag_r[i];
		assign sum6_real[i]	= add12_real_r[i] + add13_real_r[i];
		assign sum6_imag[i]	= add12_imag_r[i] + add13_imag_r[i];
		assign sum7_real[i]	= add14_real_r[i] + add15_real_r[i];
		assign sum7_imag[i]	= add14_imag_r[i] + add15_imag_r[i];

		// LEVEL 2: Add 8 sums into 4 sums.
		assign sum8_real[i]	= sum0_real_r[i] + sum1_real_r[i];
		assign sum8_imag[i]	= sum0_imag_r[i] + sum1_imag_r[i];
		assign sum9_real[i]	= sum2_real_r[i] + sum3_real_r[i];
		assign sum9_imag[i]	= sum2_imag_r[i] + sum3_imag_r[i];
		assign sum10_real[i]	= sum4_real_r[i] + sum5_real_r[i];
		assign sum10_imag[i]	= sum4_imag_r[i] + sum5_imag_r[i];
		assign sum11_real[i]	= sum6_real_r[i] + sum7_real_r[i];
		assign sum11_imag[i]	= sum6_imag_r[i] + sum7_imag_r[i];

		// LEVEL 3: Add 4 sums into 2 sums.
		assign sum12_real[i]	= sum8_real_r[i] + sum9_real_r[i];
		assign sum12_imag[i]	= sum8_imag_r[i] + sum9_imag_r[i];
		assign sum13_real[i]	= sum10_real_r[i] + sum11_real_r[i];
		assign sum13_imag[i]	= sum10_imag_r[i] + sum11_imag_r[i];

		// LEVEL 4: Add 2 sums into final result.
		assign sum14_real[i]	= sum12_real_r[i] + sum13_real_r[i];
		assign sum14_imag[i]	= sum12_imag_r[i] + sum13_imag_r[i];

		// Updated for 16 tones
		assign dout_real[i] =	(qsel_la == 1)?	sum14_real_r[i][15:0]	:
								(qsel_la == 2)? sum14_real_r[i][16:1]	:		
								(qsel_la <= 4)? sum14_real_r[i][17:2]	:		
								(qsel_la <= 8)? sum14_real_r[i][18:3]	:		
								sum14_real_r[i][19:4];
		assign dout_imag[i] =	(qsel_la == 1)?	sum14_imag_r[i][15:0]	:
								(qsel_la == 2)? sum14_imag_r[i][16:1]	:		
								(qsel_la <= 4)? sum14_imag_r[i][17:2]	:		
								(qsel_la <= 8)? sum14_imag_r[i][18:3]	:		
								sum14_imag_r[i][19:4];

		/***********/
		/* Outputs */
		/***********/
		assign m_axis_tdata_o[i*32 +: 32] = (en_int_la == 1'b1)? {dout_imag[i],dout_real[i]} : 32'h0000_0000;
	end
endgenerate

// Control block.
ctrl ctrl_i
 	(
		// Reset and clock.
		.rstn			(aresetn		),
		.clk			(aclk			),

		// Fifo interface.
		.fifo_rd_en_o	(fifo_rd_en		),
		.fifo_empty_i	(fifo_empty		),
		.fifo_dout_i	(fifo_dout		),

		// Mask output.
		.mask_o			(mask_int		),

		// Output enable.
		.en_o			(en_int			)
	);

// Latency en_int
latency_reg
	#(
		.N(5), // increased by 1, since we have an extra layer of addition
		.B(1)
	)
	en_int_latency_reg_i
	(
		.rstn	(aresetn	),
		.clk	(aclk		),

		.din	(en_int 	),
		.dout	(en_int_la	)
	);

// Latency qsel.
latency_reg
	#(
		.N(5), // increased both by 1, since we have an extra layer of addition
		.B(5) 
	)
	qsel_latency_reg_i
	(
		.rstn	(aresetn	),
		.clk	(aclk		),

		.din	(qsel 		),
		.dout	(qsel_la	)
	);

// Output selection quantization.
assign qsel = mask_int[0] + mask_int[1] + mask_int[2] + mask_int[3] + mask_int[4] + mask_int[5] + mask_int[6] + mask_int[7] + 
			  mask_int[8] + mask_int[9] + mask_int[10] + mask_int[11] + mask_int[12] + mask_int[13] + mask_int[14] + mask_int[15]; // changed to accommodate 16 tones in mask


// Assign outputs.
assign s_axis_tready_o = ~fifo_full;
assign m_axis_tvalid_o = en_int_la;

endmodule

