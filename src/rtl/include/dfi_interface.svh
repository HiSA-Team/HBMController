`ifndef DFI_INTERFACE_SVH__
`define DFI_INTERFACE_SVH__


`define DEFINE_DFI_MASTER_PORTS()                    \
    output logic           dfi_init_start,           \
    output logic  [1:0]    dfi_aw_ck_p0,             \
    output logic  [1:0]    dfi_aw_cke_p0,            \
    output logic  [11:0]   dfi_aw_row_p0,            \
    output logic  [15:0]   dfi_aw_col_p0,            \
    output logic  [255:0]  dfi_dw_wrdata_p0,         \
    output logic  [31:0]   dfi_dw_wrdata_mask_p0,    \
    output logic  [31:0]   dfi_dw_wrdata_dbi_p0,     \
    output logic  [7:0]    dfi_dw_wrdata_par_p0,     \
    output logic  [7:0]    dfi_dw_wrdata_dq_en_p0,   \
    output logic  [7:0]    dfi_dw_wrdata_par_en_p0,  \
    output logic  [1:0]    dfi_aw_ck_p1,             \
    output logic  [1:0]    dfi_aw_cke_p1,            \
    output logic  [11:0]   dfi_aw_row_p1,            \
    output logic  [15:0]   dfi_aw_col_p1,            \
    output logic  [255:0]  dfi_dw_wrdata_p1,         \
    output logic  [31:0]   dfi_dw_wrdata_mask_p1,    \
    output logic  [31:0]   dfi_dw_wrdata_dbi_p1,     \
    output logic  [7:0]    dfi_dw_wrdata_par_p1,     \
    output logic  [7:0]    dfi_dw_wrdata_dq_en_p1,   \
    output logic  [7:0]    dfi_dw_wrdata_par_en_p1,  \
    output logic           dfi_aw_ck_dis,            \
    output logic           dfi_lp_pwr_e_req,         \
    output logic           dfi_lp_sr_e_req,          \
    output logic           dfi_lp_pwr_x_req,         \
    output logic           dfi_lp_pwr_x_e_req,       \
    output logic           dfi_aw_tx_indx_ld,        \
    output logic           dfi_dw_tx_indx_ld,        \
    output logic           dfi_dw_rx_indx_ld,        \
    output logic           dfi_ctrlupd_ack,          \
    output logic           dfi_phyupd_req,           \
    input logic            dfi_init_complete,        \
    input logic   [3:0]    dfi_dw_rddata_valid,      \
    input logic   [255:0]  dfi_dw_rddata_p0,         \
    input logic   [31:0]   dfi_dw_rddata_dm_p0,      \
    input logic   [31:0]   dfi_dw_rddata_dbi_p0,     \
    input logic   [7:0]    dfi_dw_rddata_par_p0,     \
    input logic   [255:0]  dfi_dw_rddata_p1,         \
    input logic   [31:0]   dfi_dw_rddata_dm_p1,      \
    input logic   [31:0]   dfi_dw_rddata_dbi_p1,     \
    input logic   [7:0]    dfi_dw_rddata_par_p1,     \
    input logic            dfi_ctrlupd_req,          \
    input logic            dfi_phyupd_ack



`endif // DFI_INTERFACE_SVH__
