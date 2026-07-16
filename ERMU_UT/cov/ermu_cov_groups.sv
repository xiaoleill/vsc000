// =============================================================================
//  ERMU Functional Coverage Groups
//  Defines covergroups for error sources, responses, channels, and timers
// =============================================================================

package ermu_cov_groups_pkg;

    // ---- Error Response Codes ----
    typedef enum bit [2:0] {
        ERMU_NA      = 3'h0,
        ERMU_RSV     = 3'h1,
        ERMU_LPI0    = 3'h2,
        ERMU_LPI1    = 3'h3,
        ERMU_LPI2    = 3'h4,
        ERMU_HPI     = 3'h5,
        ERMU_APP_RST = 3'h6,
        ERMU_SYS_RST = 3'h7
    } err_rsp_e;

    // ---- Error Source Categories ----
    typedef enum {
        CAT_WT_ERR, CAT_WDT_ERR, CAT_FLASH_ECC, CAT_SRAM_ECC_C,
        CAT_SRAM_ECC_F, CAT_CACHE_ECC, CAT_CAN_ECC, CAT_PKE_ECC,
        CAT_DMPU_ERR, CAT_DMA_ERR, CAT_FPU_ERR, CAT_FCM_ERR, CAT_RESERVED
    } err_cat_e;

endpackage : ermu_cov_groups_pkg
