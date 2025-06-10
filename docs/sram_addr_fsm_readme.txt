This is the FSM that generates the address selection bus to the SRAM blocks.

Assumptions: 
1- The FSM is waiting for an enable pulse signal from the pixel array (SRO), indicating that the rows are ready to be fed.
2- SRO can be async, that's why the address is 0 at the first clock edge after the SRO signal is asserted.
3- A data valid signal (dv) is asserted to indicate that the current row is ready to be processes, address increment does not happen until dv pulse is asserted.
4- When the address reaches its limit (167 in the case of 168 words per SRAM), the FSM waits for another enable pulse and restarts.
