`ifndef HBM_TIMING_CONSTRAINTS_SVH__
`define HBM_TIMING_CONSTRAINTS_SVH__


// HBM intra bank timing constraints - for bank schedulers 
localparam integer    tRCD     =  32'd14;
localparam integer    tRP      =  32'd14;
localparam integer    tRC      =  32'd1;
localparam integer    tRAS     =  32'd34;
localparam integer    tWL      =  32'd4;
localparam integer    tRL      =  32'd14;
localparam integer    tRTPl    =  32'd6;
localparam integer    tWR      =  32'd16;
localparam integer    tBURST   =  32'd2;
localparam integer    tRFCpb   =  32'd73;
localparam integer    tREFP    =  32'd1220;      /* Refresh Period*/  /* Maybe it is too conservative ? */

// HBM intra and inter bank timing constraints - for LLCF     
localparam integer    tCCDl    =  32'd1;
localparam integer    tCCDs    =  32'd0;
localparam integer    tRTW     =  32'd8; 
localparam integer    tWTRl    =  32'd8;
localparam integer    tRRD     =  32'd6;
localparam integer    tFAW     =  32'd30;
localparam integer    tWTRs    =  32'd6;
localparam integer    tRREFD   =  32'd4;


`endif // HBM_TIMING_CONSTRAINTS_SVH__