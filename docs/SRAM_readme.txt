1- The SRAM.sv which is the top level containts mulitple instances of SRAM_bank which contains multiple instances of SRAM_block. 
2- Number of SRAM_bank instances in the SRAM equals the value of K.
3- The number or SRAM_block instances in the SRAM_bank is equal to the number of columns in the pixel array.
4- The number of cells in the SRAM_block is equal to the number of rows in the pixel array.
5-  The data width in the SRAM_block is equal to the width of the weight which depends on the precision
