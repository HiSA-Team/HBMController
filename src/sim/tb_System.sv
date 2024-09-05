`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12.07.2024 15:16:44
// Design Name: 
// Module Name: tb_System
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tb_System1;


  // Segnali di testbench
  logic clock;
  logic reset;
  logic [15:0] init_axi_txn;
  logic [15:0] txn_done;
  logic [15:0] error ;
  logic clock_450;

  // Instanziazione del modulo sotto test (UUT)
  System uut (
    .clock(clock),
    .reset(reset),
    .init_axi_txn(init_axi_txn),
    .txn_done(txn_done),
    .error(error),
    
    .clock_450(clock_450)
  );

  // Generazione del clock
  initial begin
    clock = 0;
    forever #7 clock = ~clock; // Clock a 100 MHz (periodo di 10 ns)
  end
  
  initial begin
    clock_450 = 0;
    forever #4 clock_450 = ~clock_450; // Clock a 100 MHz (periodo di 10 ns)
  end

  // Reset iniziale
  initial begin
    //reset = 1;
    #20;
    reset = 0;
  end

  // Stimolo del testbench
  initial begin
    // Inizializzazione dei segnali
    
    // Attendere il reset
    @(negedge reset);

    // Inizio transazione AXI
    init_axi_txn = {16{1'b1}};
    #10;
    init_axi_txn = {16{1'b0}};

    // Attendere che la transazione sia completata
    wait(txn_done == {16{1'b1}});

    // Controllo errori
    if (error) begin
      $display("Test fallito con errore.");
    end else begin
      $display("Test completato con successo.");
    end

    // Fine della simulazione
    #100;
    $stop;
  end

endmodule
