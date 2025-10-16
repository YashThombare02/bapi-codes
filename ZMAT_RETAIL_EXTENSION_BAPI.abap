*&---------------------------------------------------------------------*
*& Report  ZMAT_RETAIL_EXTENSION_BAPI
*&---------------------------------------------------------------------*
*& Program to extend retail materials from source plant to target plant
*& using BAPI_MATERIAL_SAVEDATA
*&---------------------------------------------------------------------*
*& Author: Rishika
*& Date: October 16, 2025
*&---------------------------------------------------------------------*

REPORT zmat_retail_extension_bapi.

*----------------------------------------------------------------------*
* Type Pools
*----------------------------------------------------------------------*
TYPE-POOLS: slis.

*----------------------------------------------------------------------*
* Types Declaration
*----------------------------------------------------------------------*
TYPES: BEGIN OF ty_retail_mat,
         material          TYPE matnr,            " Material Number
         ind_sector        TYPE mbrsh,            " Industry Sector
         material_type     TYPE mtart,            " Material Type
         plant             TYPE werks_d,          " Plant
         stor_loc          TYPE lgort_d,          " Storage Location
         sales_org         TYPE vkorg,            " Sales Organization
         distr_chnl        TYPE vtweg,            " Distribution Channel
         description       TYPE maktx,            " Material Description
         base_uom          TYPE meins,            " Base Unit of Measure
         matl_group        TYPE matkl,            " Material Group
         ext_matl_group    TYPE wgbez,            " External Material Group
         old_mat_no        TYPE bismt,            " Old Material Number
         division          TYPE spart,            " Division
         gross_weight      TYPE brgew,            " Gross Weight
         net_weight        TYPE ntgew,            " Net Weight
         size_dimensions   TYPE groes,            " Size/Dimensions
         weight_unit       TYPE gewei,            " Weight Unit
         volume            TYPE volum,            " Volume
         matl_grp_packaging TYPE mgrke,           " Material Group Packaging Materials
         ref_mat_packaging  TYPE magrv,           " Reference Material for Packaging
         val_class         TYPE bklas,            " Valuation Class
         price_ctrl        TYPE vprsv,            " Price Control
         moving_price      TYPE verpr,            " Moving Average Price
         std_price         TYPE stprs,            " Standard Price
         mrp_type          TYPE dismm,            " MRP Type
         mrp_controller    TYPE dispo,            " MRP Controller
         batch_mgmt        TYPE xfeld,            " Batch Management
         proc_type         TYPE beskz,            " Procurement Type
         special_proc      TYPE sobsl,            " Special Procurement Type
         prod_stor_loc     TYPE lgpro,            " Production Storage Location
         sales_unit        TYPE vrkme,            " Sales Unit
         qual_insp_type    TYPE qmpur,            " Quality Inspection Type
         serial_no_profile TYPE serail,           " Serial Number Profile
         ean_upc           TYPE ean11,            " EAN/UPC
         profit_center     TYPE prctr,            " Profit Center
         costing_lot_size  TYPE losgr,            " Costing Lot Size
         tax_ind_material  TYPE mstae,            " Tax Indicator for Material
         hsn_code          TYPE j_1imkey,         " HSN Code
         merch_category    TYPE wwmt1,            " Merchandise Category (Retail)
         article_hierarchy TYPE wwmt3,            " Article Hierarchy (Retail)
         season            TYPE wsaiso,           " Season (Retail)
         assortment        TYPE wsoh1,            " Assortment (Retail)
         from_plant        TYPE werks_d,          " Source Plant
       END OF ty_retail_mat.

*----------------------------------------------------------------------*
* Data Declaration
*----------------------------------------------------------------------*
DATA: gt_retail_mat     TYPE TABLE OF ty_retail_mat,
      gs_retail_mat     TYPE ty_retail_mat,
      gv_filename       TYPE string,
      gv_answer         TYPE c,
      gv_error          TYPE c,
      gv_msg            TYPE string,
      gv_material_count TYPE i.

* Internal tables for BAPI
DATA: gt_clientdata      TYPE TABLE OF bapiclient,
      gt_clientdatax     TYPE TABLE OF bapiclientx,
      gt_materialdesc    TYPE TABLE OF bapimatdesc,
      gt_materialplant   TYPE TABLE OF bapimgvlmat,
      gt_materialplantx  TYPE TABLE OF bapimgvlmatx,
      gt_matvaluation    TYPE TABLE OF bapimatval,
      gt_matvaluationx   TYPE TABLE OF bapimatvalx,
      gt_storageloc      TYPE TABLE OF bapimatloc,
      gt_storagelocx     TYPE TABLE OF bapimatlocx,
      gt_salesdata       TYPE TABLE OF bapimatsales,
      gt_salesdatax      TYPE TABLE OF bapimatsalesx,
      gt_return_msgs     TYPE TABLE OF bapiret2,
      gt_extensionin     TYPE TABLE OF bapiparex,
      gt_extensioninx    TYPE TABLE OF bapiparexx.

* Work areas for BAPI
DATA: gs_clientdata      TYPE bapiclient,
      gs_clientdatax     TYPE bapiclientx,
      gs_materialdesc    TYPE bapimatdesc,
      gs_materialplant   TYPE bapimgvlmat,
      gs_materialplantx  TYPE bapimgvlmatx,
      gs_matvaluation    TYPE bapimatval,
      gs_matvaluationx   TYPE bapimatvalx,
      gs_storageloc      TYPE bapimatloc,
      gs_storagelocx     TYPE bapimatlocx,
      gs_salesdata       TYPE bapimatsales,
      gs_salesdatax      TYPE bapimatsalesx,
      gs_extensionin     TYPE bapiparex,
      gs_extensioninx    TYPE bapiparexx,
      gs_headdata        TYPE bapimathead,
      gs_return          TYPE bapiret2.
      
* Retail-specific tables and structures
DATA: gt_article_list    TYPE TABLE OF bapi_mara_retail,
      gs_article_list    TYPE bapi_mara_retail,
      gt_retail_data     TYPE TABLE OF bapi_marart,
      gs_retail_data     TYPE bapi_marart,
      gt_retail_datax    TYPE TABLE OF bapi_marartx,
      gs_retail_datax    TYPE bapi_marartx,
      gt_site_list       TYPE TABLE OF bapi_site_list,
      gs_site_list       TYPE bapi_site_list,
      gt_site_detail     TYPE TABLE OF bapi_site_detail,
      gs_site_detail     TYPE bapi_site_detail.

* ALV variables
DATA: gt_fieldcat        TYPE slis_t_fieldcat_alv,
      gs_layout          TYPE slis_layout_alv.

*----------------------------------------------------------------------*
* Selection Screen
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE text-001.
PARAMETERS: p_file TYPE string OBLIGATORY,       " File path for Excel upload
            p_test TYPE c AS CHECKBOX DEFAULT 'X'. " Test run (no updates)
SELECTION-SCREEN END OF BLOCK b1.

*----------------------------------------------------------------------*
* Start of Selection
*----------------------------------------------------------------------*
START-OF-SELECTION.
  PERFORM upload_file.
  PERFORM process_data.
  PERFORM display_result.

*&---------------------------------------------------------------------*
*& Form UPLOAD_FILE
*&---------------------------------------------------------------------*
* Upload data from Excel file
*&---------------------------------------------------------------------*
FORM upload_file.
  DATA: lt_raw TYPE truxs_t_text_data.
  
  gv_filename = p_file.

  CALL FUNCTION 'GUI_UPLOAD'
    EXPORTING
      filename                = gv_filename
      filetype                = 'ASC'
      has_field_separator     = 'X'
    TABLES
      data_tab                = lt_raw
    EXCEPTIONS
      file_open_error         = 1
      file_read_error         = 2
      no_batch                = 3
      gui_refuse_filetransfer = 4
      invalid_type            = 5
      no_authority            = 6
      unknown_error           = 7
      bad_data_format         = 8
      header_not_allowed      = 9
      separator_not_allowed   = 10
      header_too_long         = 11
      unknown_dp_error        = 12
      access_denied           = 13
      dp_out_of_memory        = 14
      disk_full               = 15
      dp_timeout              = 16
      OTHERS                  = 17.

  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
            WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.

  * Convert raw data to internal table
  CALL FUNCTION 'TEXT_CONVERT_XLS_TO_SAP'
    EXPORTING
      i_line_header        = 'X'
      i_tab_raw_data       = lt_raw
    TABLES
      i_tab_converted_data = gt_retail_mat
    EXCEPTIONS
      conversion_failed    = 1
      OTHERS               = 2.

  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
            WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.

  * Check if data was loaded
  DESCRIBE TABLE gt_retail_mat LINES gv_material_count.
  IF gv_material_count = 0.
    MESSAGE 'No data found in upload file' TYPE 'E'.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form PROCESS_DATA
*&---------------------------------------------------------------------*
* Process data and call BAPI for material extension
*&---------------------------------------------------------------------*
FORM process_data.
  DATA: lv_answer TYPE c,
        lv_msg    TYPE string.

  IF gt_retail_mat[] IS INITIAL.
    MESSAGE 'No data found in upload file' TYPE 'E'.
    RETURN.
  ENDIF.

  CONCATENATE 'Process' gv_material_count 'materials?' INTO lv_msg SEPARATED BY space.

  CALL FUNCTION 'POPUP_TO_CONFIRM'
    EXPORTING
      titlebar              = 'Confirmation'
      text_question         = lv_msg
      text_button_1         = 'Yes'
      text_button_2         = 'No'
      default_button        = '1'
      display_cancel_button = 'X'
    IMPORTING
      answer                = lv_answer
    EXCEPTIONS
      text_not_found        = 1
      OTHERS                = 2.

  IF lv_answer <> '1'.
    MESSAGE 'Processing cancelled by user' TYPE 'I'.
    RETURN.
  ENDIF.

  LOOP AT gt_retail_mat INTO gs_retail_mat.
    CLEAR: gs_headdata, gs_clientdata, gs_clientdatax, gs_materialdesc,
           gs_materialplant, gs_materialplantx, gs_matvaluation, gs_matvaluationx,
           gs_storageloc, gs_storagelocx, gs_salesdata, gs_salesdatax,
           gs_retail_data, gs_retail_datax, gs_article_list, gs_site_list, gs_site_detail,
           gt_clientdata, gt_clientdatax, gt_materialdesc, gt_materialplant, 
           gt_materialplantx, gt_matvaluation, gt_matvaluationx, gt_storageloc,
           gt_storagelocx, gt_salesdata, gt_salesdatax, gt_extensionin,
           gt_extensioninx, gt_return_msgs, gt_retail_data, gt_retail_datax,
           gt_article_list, gt_site_list, gt_site_detail.

    * Convert material number to internal format
    CALL FUNCTION 'CONVERSION_EXIT_MATN1_INPUT'
      EXPORTING
        input        = gs_retail_mat-material
      IMPORTING
        output       = gs_retail_mat-material
      EXCEPTIONS
        length_error = 1
        OTHERS       = 2.
        
    * Set material header data
    gs_headdata-material       = gs_retail_mat-material.
    gs_headdata-ind_sector     = gs_retail_mat-ind_sector.       " Retail (T = Retail)
    gs_headdata-matl_type      = gs_retail_mat-material_type.
    gs_headdata-basic_view     = 'X'.
    gs_headdata-sales_view     = 'X'.
    gs_headdata-purchase_view  = 'X'.
    gs_headdata-mrp_view       = 'X'.
    gs_headdata-forecast_view  = 'X'.
    gs_headdata-work_sched_view = 'X'.
    gs_headdata-prt_view       = 'X'.
    gs_headdata-storage_view   = 'X'.
    gs_headdata-warehouse_view = 'X'.
    gs_headdata-quality_view   = 'X'.
    gs_headdata-account_view   = 'X'.
    gs_headdata-cost_view      = 'X'.

    * Set client data - General Material Data
    gs_clientdata-material     = gs_retail_mat-material.
    gs_clientdata-matl_group   = gs_retail_mat-matl_group.
    gs_clientdata-old_mat_no   = gs_retail_mat-old_mat_no.
    gs_clientdata-base_uom     = gs_retail_mat-base_uom.
    gs_clientdata-division     = gs_retail_mat-division.
    gs_clientdata-net_weight   = gs_retail_mat-net_weight.
    gs_clientdata-unit_of_wt   = gs_retail_mat-weight_unit.
    gs_clientdata-size_dim     = gs_retail_mat-size_dimensions.
    gs_clientdata-extmatlgrp   = gs_retail_mat-ext_matl_group.
    gs_clientdata-mat_grp_sm   = gs_retail_mat-matl_grp_packaging.
    gs_clientdata-pl_ref_mat   = gs_retail_mat-ref_mat_packaging.
    gs_clientdata-batch_mgmt   = gs_retail_mat-batch_mgmt.

    * Mark fields as updated
    gs_clientdatax-material    = gs_retail_mat-material.
    gs_clientdatax-matl_group  = 'X'.
    gs_clientdatax-old_mat_no  = 'X'.
    gs_clientdatax-base_uom    = 'X'.
    gs_clientdatax-division    = 'X'.
    gs_clientdatax-net_weight  = 'X'.
    gs_clientdatax-unit_of_wt  = 'X'.
    gs_clientdatax-size_dim    = 'X'.
    gs_clientdatax-extmatlgrp  = 'X'.
    gs_clientdatax-mat_grp_sm  = 'X'.
    gs_clientdatax-pl_ref_mat  = 'X'.
    gs_clientdatax-batch_mgmt  = 'X'.

    APPEND gs_clientdata TO gt_clientdata.
    APPEND gs_clientdatax TO gt_clientdatax.
    
    * Set retail-specific data
    gs_retail_data-material    = gs_retail_mat-material.
    gs_retail_data-merch_cat   = gs_retail_mat-merch_category.      " Merchandise Category
    gs_retail_data-article_hier = gs_retail_mat-article_hierarchy.  " Article Hierarchy
    gs_retail_data-season      = gs_retail_mat-season.              " Season

    * Mark retail fields as updated
    gs_retail_datax-material   = gs_retail_mat-material.
    gs_retail_datax-merch_cat  = 'X'.
    gs_retail_datax-article_hier = 'X'.
    gs_retail_datax-season     = 'X'.

    APPEND gs_retail_data TO gt_retail_data.
    APPEND gs_retail_datax TO gt_retail_datax.
    
    * Add article to article list
    gs_article_list-material   = gs_retail_mat-material.
    APPEND gs_article_list TO gt_article_list.
    
    * Site data (plant/store in retail)
    gs_site_list-material      = gs_retail_mat-material.
    gs_site_list-site          = gs_retail_mat-plant.
    APPEND gs_site_list TO gt_site_list.
    
    gs_site_detail-material    = gs_retail_mat-material.
    gs_site_detail-site        = gs_retail_mat-plant.
    APPEND gs_site_detail TO gt_site_detail.

    * Set material description
    gs_materialdesc-material   = gs_retail_mat-material.
    gs_materialdesc-langu      = 'E'.          " English
    gs_materialdesc-matl_desc  = gs_retail_mat-description.
    APPEND gs_materialdesc TO gt_materialdesc.

    * Set material plant data
    gs_materialplant-material  = gs_retail_mat-material.
    gs_materialplant-plant     = gs_retail_mat-plant.
    gs_materialplant-mrp_type  = gs_retail_mat-mrp_type.
    gs_materialplant-mrp_ctrler = gs_retail_mat-mrp_controller.
    gs_materialplant-proc_type = gs_retail_mat-proc_type.
    gs_materialplant-spproctype = gs_retail_mat-special_proc.
    gs_materialplant-iss_st_loc = gs_retail_mat-prod_stor_loc.
    gs_materialplant-profit_ctr = gs_retail_mat-profit_center.
    gs_materialplant-batch_mgmt = gs_retail_mat-batch_mgmt.
    gs_materialplant-serial_no_profile = gs_retail_mat-serial_no_profile.

    * Mark plant fields as updated
    gs_materialplantx-material = gs_retail_mat-material.
    gs_materialplantx-plant    = gs_retail_mat-plant.
    gs_materialplantx-mrp_type = 'X'.
    gs_materialplantx-mrp_ctrler = 'X'.
    gs_materialplantx-proc_type = 'X'.
    gs_materialplantx-spproctype = 'X'.
    gs_materialplantx-iss_st_loc = 'X'.
    gs_materialplantx-profit_ctr = 'X'.
    gs_materialplantx-batch_mgmt = 'X'.
    gs_materialplantx-serial_no_profile = 'X'.

    APPEND gs_materialplant TO gt_materialplant.
    APPEND gs_materialplantx TO gt_materialplantx.

    * Set material valuation data
    gs_matvaluation-material   = gs_retail_mat-material.
    gs_matvaluation-val_area   = gs_retail_mat-plant.   " Valuation Area = Plant
    gs_matvaluation-val_class  = gs_retail_mat-val_class.
    gs_matvaluation-price_ctrl = gs_retail_mat-price_ctrl.
    gs_matvaluation-price_unit = 1.
    
    * Set price based on price control
    IF gs_retail_mat-price_ctrl = 'S'.        " Standard Price
      gs_matvaluation-std_price = gs_retail_mat-std_price.
    ELSE.                                     " Moving Average Price
      gs_matvaluation-moving_pr = gs_retail_mat-moving_price.
    ENDIF.
    
    * Mark valuation fields as updated
    gs_matvaluationx-material  = gs_retail_mat-material.
    gs_matvaluationx-val_area  = gs_retail_mat-plant.
    gs_matvaluationx-val_class = 'X'.
    gs_matvaluationx-price_ctrl = 'X'.
    gs_matvaluationx-price_unit = 'X'.
    
    IF gs_retail_mat-price_ctrl = 'S'.
      gs_matvaluationx-std_price = 'X'.
    ELSE.
      gs_matvaluationx-moving_pr = 'X'.
    ENDIF.
    
    APPEND gs_matvaluation TO gt_matvaluation.
    APPEND gs_matvaluationx TO gt_matvaluationx.
    
    * Set storage location data
    IF gs_retail_mat-stor_loc IS NOT INITIAL.
      gs_storageloc-material = gs_retail_mat-material.
      gs_storageloc-plant    = gs_retail_mat-plant.
      gs_storageloc-stge_loc = gs_retail_mat-stor_loc.
      
      * Mark storage location fields as updated
      gs_storagelocx-material = gs_retail_mat-material.
      gs_storagelocx-plant    = gs_retail_mat-plant.
      gs_storagelocx-stge_loc = gs_retail_mat-stor_loc.
      gs_storagelocx-authorization = 'X'.
      
      APPEND gs_storageloc TO gt_storageloc.
      APPEND gs_storagelocx TO gt_storagelocx.
    ENDIF.
    
    * Set sales organization data
    IF gs_retail_mat-sales_org IS NOT INITIAL.
      gs_salesdata-material  = gs_retail_mat-material.
      gs_salesdata-sales_org = gs_retail_mat-sales_org.
      
      * Set distribution channel if provided
      IF gs_retail_mat-distr_chnl IS NOT INITIAL.
        gs_salesdata-distr_chnl = gs_retail_mat-distr_chnl.
      ENDIF.
      
      * Set division if provided
      IF gs_retail_mat-division IS NOT INITIAL.
        gs_salesdata-division = gs_retail_mat-division.
      ENDIF.
      
      gs_salesdata-sales_unit = gs_retail_mat-sales_unit.
      
      * Mark sales fields as updated
      gs_salesdatax-material  = gs_retail_mat-material.
      gs_salesdatax-sales_org = gs_retail_mat-sales_org.
      
      IF gs_retail_mat-distr_chnl IS NOT INITIAL.
        gs_salesdatax-distr_chnl = 'X'.
      ENDIF.
      
      IF gs_retail_mat-division IS NOT INITIAL.
        gs_salesdatax-division = 'X'.
      ENDIF.
      
      gs_salesdatax-sales_unit = 'X'.
      
      APPEND gs_salesdata TO gt_salesdata.
      APPEND gs_salesdatax TO gt_salesdatax.
    ENDIF.

    * Process retail material
    IF p_test = 'X'.
      * Test mode - don't perform actual extension
      WRITE: / 'Test mode: Material', gs_retail_mat-material, 'would be extended to plant', 
               gs_retail_mat-plant.
      CONTINUE.
    ENDIF.

    * Call BAPI to extend the retail material
    CALL FUNCTION 'BAPI_MATERIAL_SAVEDATA'
      EXPORTING
        headdata             = gs_headdata
      TABLES
        clientdata           = gt_clientdata
        clientdatax          = gt_clientdatax
        materialdescription  = gt_materialdesc
        plantdata            = gt_materialplant
        plantdatax           = gt_materialplantx
        valuationdata        = gt_matvaluation
        valuationdatax       = gt_matvaluationx
        storagelocationdata  = gt_storageloc
        storagelocationdatax = gt_storagelocx
        salesdata            = gt_salesdata
        salesdatax           = gt_salesdatax
        extensionin          = gt_extensionin
        extensioninx         = gt_extensioninx
        return               = gt_return_msgs.

    READ TABLE gt_return_msgs WITH KEY type = 'E' TRANSPORTING NO FIELDS.
    IF sy-subrc = 0.
      gv_error = 'X'.
      WRITE: / 'Error in standard material data for', gs_retail_mat-material, '. Trying retail-specific extension...'.
      
      * If standard BAPI fails, try retail-specific BAPI
      PERFORM extend_retail_material.
    ELSE.
      * Standard BAPI successful, now add retail-specific data
      PERFORM update_retail_data.
      
      * Commit the BAPI
      CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
        EXPORTING
          wait = 'X'.
          
      WRITE: / 'Material', gs_retail_mat-material, 'successfully extended to plant', gs_retail_mat-plant.
    ENDIF.

  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form EXTEND_RETAIL_MATERIAL
*&---------------------------------------------------------------------*
* Extend material using retail-specific BAPI functions
*&---------------------------------------------------------------------*
FORM extend_retail_material.
  DATA: lt_retail_return TYPE TABLE OF bapiret2,
        ls_retail_return TYPE bapiret2,
        lt_wmaterial     TYPE TABLE OF bapi_te_wmara,
        ls_wmaterial     TYPE bapi_te_wmara,
        lt_wmaterialx    TYPE TABLE OF bapi_te_wmarax,
        ls_wmaterialx    TYPE bapi_te_wmarax.
  
  * First, try to get the source material data
  CALL FUNCTION 'BAPI_MATERIAL_GET_DETAIL'
    EXPORTING
      material              = gs_retail_mat-material
      plant                 = gs_retail_mat-from_plant
    TABLES
      return                = lt_retail_return.
  
  READ TABLE lt_retail_return WITH KEY type = 'E' TRANSPORTING NO FIELDS.
  IF sy-subrc = 0.
    WRITE: / 'Error retrieving source material data for', gs_retail_mat-material.
    LOOP AT lt_retail_return INTO ls_retail_return WHERE type = 'E'.
      WRITE: / ls_retail_return-message.
    ENDLOOP.
    RETURN.
  ENDIF.
  
  * Set up retail material extension data
  ls_wmaterial-matnr = gs_retail_mat-material.
  ls_wmaterial-mbrsh = 'T'.  " Retail industry sector
  ls_wmaterial-mtart = gs_retail_mat-material_type.
  ls_wmaterial-ersda = sy-datum.  " Creation date
  ls_wmaterial-ernam = sy-uname.  " Created by
  
  * Mark fields for update
  ls_wmaterialx-matnr = gs_retail_mat-material.
  ls_wmaterialx-mbrsh = 'X'.
  ls_wmaterialx-mtart = 'X'.
  ls_wmaterialx-ersda = 'X'.
  ls_wmaterialx-ernam = 'X'.
  
  APPEND ls_wmaterial TO lt_wmaterial.
  APPEND ls_wmaterialx TO lt_wmaterialx.
  
  * Set retail extension field in EXTENSIONIN table
  gs_extensionin-structure = 'BAPI_TE_WMARA'.
  gs_extensionin-valuepart1 = ls_wmaterial.
  APPEND gs_extensionin TO gt_extensionin.
  
  gs_extensioninx-structure = 'BAPI_TE_WMARAX'.
  gs_extensioninx-valuepart1 = ls_wmaterialx.
  APPEND gs_extensioninx TO gt_extensioninx.
  
  * Call retail-specific BAPI
  CALL FUNCTION 'BAPI_ARTICLE_MAINTAIN'
    TABLES
      articlelist       = gt_article_list
      retaildata        = gt_retail_data
      retaildatax       = gt_retail_datax
      sitelist          = gt_site_list
      sitedetail        = gt_site_detail
      materialdescription = gt_materialdesc
      return            = lt_retail_return.

  READ TABLE lt_retail_return WITH KEY type = 'E' TRANSPORTING NO FIELDS.
  IF sy-subrc = 0.
    WRITE: / 'Error extending retail material', gs_retail_mat-material, 'to plant', gs_retail_mat-plant.
    LOOP AT lt_retail_return INTO ls_retail_return WHERE type = 'E'.
      WRITE: / ls_retail_return-message.
    ENDLOOP.
  ELSE.
    * Now commit the transaction
    CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
      EXPORTING
        wait = 'X'.
        
    WRITE: / 'Retail material', gs_retail_mat-material, 'successfully extended to plant', gs_retail_mat-plant.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form UPDATE_RETAIL_DATA
*&---------------------------------------------------------------------*
* Update retail-specific data for a material
*&---------------------------------------------------------------------*
FORM update_retail_data.
  DATA: lt_retail_return TYPE TABLE OF bapiret2,
        ls_retail_return TYPE bapiret2.
  
  * Call retail-specific BAPI to update retail fields
  CALL FUNCTION 'BAPI_ARTICLE_MAINTAIN'
    TABLES
      articlelist       = gt_article_list
      retaildata        = gt_retail_data
      retaildatax       = gt_retail_datax
      sitelist          = gt_site_list
      sitedetail        = gt_site_detail
      return            = lt_retail_return.

  READ TABLE lt_retail_return WITH KEY type = 'E' TRANSPORTING NO FIELDS.
  IF sy-subrc = 0.
    WRITE: / 'Warning: Standard material data saved, but error updating retail data for', gs_retail_mat-material.
    LOOP AT lt_retail_return INTO ls_retail_return WHERE type = 'E'.
      WRITE: / ls_retail_return-message.
    ENDLOOP.
  ELSE.
    * Commit the BAPI for retail data
    CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
      EXPORTING
        wait = 'X'.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form DISPLAY_RESULT
*&---------------------------------------------------------------------*
* Display processing results
*&---------------------------------------------------------------------*
FORM display_result.

  * If there were errors, display summary
  IF gv_error = 'X'.
    MESSAGE 'There were errors during retail material extension. Check the list for details.' TYPE 'I'.
  ELSE.
    IF p_test = 'X'.
      MESSAGE 'Test run completed successfully. No changes were made.' TYPE 'S'.
    ELSE.
      MESSAGE 'All retail materials were extended successfully.' TYPE 'S'.
    ENDIF.
  ENDIF.

ENDFORM.
