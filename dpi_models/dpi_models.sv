/* 
 * dev_dpi.sv
 * Germain Haugou <haugoug@iis.ee.ethz.ch>
 *
 * Copyright (C) 2013-2018 ETH Zurich, University of Bologna.
 *
 * Copyright and related rights are licensed under the Solderpad Hardware
 * License, Version 0.51 (the "License"); you may not use this file except in
 * compliance with the License.  You may obtain a copy of the License at
 * http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
 * or agreed to in writing, software, hardware and materials distributed under
 * this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
 * CONDITIONS OF ANY KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations under the License.
 *
 */

interface QSPI_CS  ();

  logic csn;

endinterface



interface QSPI ();

  logic sck;
  logic data_0_in;
  logic data_0_out;
  logic data_1_in;
  logic data_1_out;
  logic data_2_in;
  logic data_2_out;
  logic data_3_in;
  logic data_3_out;

endinterface



interface JTAG ();

  logic tck;
  logic tdi;
  logic tdo;
  logic tms;
  logic trst;

endinterface


interface UART ();

  logic tx;
  logic rx;

endinterface



interface CTRL ();

  logic reset;

endinterface



package dpi_models;

  virtual JTAG    jtag_itf_array[];
  int             nb_jtag_itf = 0;

  virtual UART    uart_itf_array[];
  int             nb_uart_itf = 0;

  virtual CTRL    ctrl_itf_array[];
  int             nb_ctrl_itf = 0;

  virtual QSPI    qspim_itf_array[];
  int             nb_qspim_itf = 0;

  import "DPI-C"   context function void dpi_uart_edge(chandle handle, longint timestamp, longint data);
  import "DPI-C"   context function void dpi_qspim_cs_edge(chandle handle, longint timestamp, input logic csn);
  import "DPI-C"   context function void dpi_qspim_sck_edge(chandle handle, longint timestamp, input logic sck, input logic data_0, input logic data_1, input logic data_2, input logic data_3);
  import "DPI-C"   context function chandle dpi_qspim_bind(chandle dpi_model, string name, int handle);
  import "DPI-C"   context function chandle dpi_jtag_bind(chandle dpi_model, string name, int handle);
  import "DPI-C"   context function chandle dpi_uart_bind(chandle dpi_model, string name, int handle);
  import "DPI-C"   context function chandle dpi_ctrl_bind(chandle dpi_model, string name, int handle);
  import "DPI-C"   context task dpi_start_task(int id);

  import "DPI-C"   context function chandle dpi_model_load(chandle comp_config, chandle handle);
  import "DPI-C"   context task dpi_model_start(chandle model);

  export "DPI-C"   task             dpi_create_task;
  export "DPI-C"   function         dpi_print;
  export "DPI-C"   function         dpi_fatal;
  export "DPI-C"   function         dpi_jtag_tck_edge;
  export "DPI-C"   function         dpi_uart_rx_edge;
  export "DPI-C"   function         dpi_ctrl_reset_edge;
  export "DPI-C"   function         dpi_qspim_set_data;
  export "DPI-C"   task             dpi_wait;
  export "DPI-C"   task             dpi_wait_ps;
  export "DPI-C"   task             dpi_wait_event;
  export "DPI-C"   task             dpi_raise_event;

  task dpi_wait(chandle handle, input longint t);
    #(t * 1ns);
  endtask

  task dpi_wait_ps(chandle handle, input longint t);
    #(t * 1ps);
  endtask

  task dpi_wait_event(chandle handle);
    #(50 * 1ns);
  endtask

  task dpi_raise_event(chandle handle);
  endtask

  function void dpi_print(chandle handle, input string msg);
    $display("[TB] %t - %s", $realtime, msg);
  endfunction : dpi_print

  function void dpi_fatal(chandle handle, input string msg);
    $display("[TB] %t - %s", $realtime, msg);
  endfunction : dpi_fatal


  function void dpi_jtag_tck_edge(int handle, int tck, int tdi, int tms, int trst, output int tdo);
    automatic virtual JTAG itf = jtag_itf_array[handle];
    itf.tck = tck;
    itf.tdi = tdi;
    itf.tms = tms;
    itf.trst = trst;
    tdo = itf.tdo;
  endfunction : dpi_jtag_tck_edge


  function void dpi_uart_rx_edge(int handle, int data);
    automatic virtual UART itf = uart_itf_array[handle];
    itf.tx = data;
  endfunction : dpi_uart_rx_edge


  function void dpi_ctrl_reset_edge(int handle, int reset);
    automatic virtual CTRL itf = ctrl_itf_array[handle];
    itf.reset = reset;
  endfunction : dpi_ctrl_reset_edge


  function void dpi_qspim_set_data(int handle, int data_0, int data_1, int data_2, int data_3);
    automatic virtual QSPI itf = qspim_itf_array[handle];
    itf.data_0_out = data_0;
    itf.data_1_out = data_1;
    itf.data_2_out = data_2;
    itf.data_3_out = data_3;
  endfunction : dpi_qspim_set_data


  task dpi_create_task(chandle handle, int id);
    $display("[TB] %t - Starting task id %d", $realtime, id);
    fork
      automatic int my_id = id;
      dpi_start_task(my_id);
    join_none
  endtask

  class periph_wrapper #(int NB_SPIS_CHANNELS = 0);

    virtual QSPI    qspi_itf;
    virtual QSPI_CS qspi_cs_itf;
    chandle dpi_model;

    function int load_model(chandle comp_config);
      dpi_model = dpi_model_load(comp_config, null);
      if (dpi_model == null) return -1;
      return 0;
    endfunction

    task start_model();
      dpi_model_start(dpi_model);
    endtask


    task jtag_bind(string name, virtual JTAG jtag_itf);
      chandle dpi_context;

      jtag_itf.tck = 'b1;
      jtag_itf.tdi = 'b1;
      jtag_itf.tms = 'b1;
      jtag_itf.trst = 'b1;

      nb_jtag_itf = nb_jtag_itf + 1;
      jtag_itf_array = new[nb_jtag_itf](jtag_itf_array);
      jtag_itf_array[nb_jtag_itf - 1] = jtag_itf;

      dpi_context = dpi_jtag_bind(dpi_model, name, nb_jtag_itf - 1);
    endtask

    task uart_bind(string name, virtual UART uart_itf);
      chandle dpi_handle;

      uart_itf.tx = 'b1;

      nb_uart_itf = nb_uart_itf + 1;
      uart_itf_array = new[nb_uart_itf](uart_itf_array);
      uart_itf_array[nb_uart_itf - 1] = uart_itf;

      dpi_handle = dpi_uart_bind(dpi_model, name, nb_uart_itf - 1);

      fork
      do begin
        @(edge uart_itf.rx);
        dpi_uart_edge(dpi_handle, $realtime*1000, uart_itf.rx);
      end while(1);
      join_none
    endtask


    task ctrl_bind(string name, virtual CTRL ctrl_itf);
      chandle dpi_context;

      $display("[TB] %t - SETTING RESET TO 1", $realtime);
      ctrl_itf.reset = 'b1;

      nb_ctrl_itf = nb_ctrl_itf + 1;
      ctrl_itf_array = new[nb_ctrl_itf](ctrl_itf_array);
      ctrl_itf_array[nb_ctrl_itf - 1] = ctrl_itf;

      dpi_context = dpi_ctrl_bind(dpi_model, name, nb_ctrl_itf - 1);
    endtask


    task qpim_bind(string name, virtual QSPI qspi_itf, virtual QSPI_CS qspi_cs_itf);

      chandle dpi_handle;

      qspi_itf.data_0_out = 'bz;
      qspi_itf.data_1_out = 'bz;
      qspi_itf.data_2_out = 'bz;
      qspi_itf.data_3_out = 'bz;

      nb_qspim_itf = nb_qspim_itf + 1;
      qspim_itf_array = new[nb_qspim_itf](qspim_itf_array);
      qspim_itf_array[nb_qspim_itf - 1] = qspi_itf;

      dpi_handle = dpi_qspim_bind(dpi_model, name, nb_qspim_itf - 1);

      this.qspi_itf = qspi_itf;
      this.qspi_cs_itf = qspi_cs_itf;
      fork
      do begin

        @(negedge qspi_cs_itf.csn);
        dpi_qspim_cs_edge(dpi_handle, $realtime*1000, qspi_cs_itf.csn);

        do begin
          @(edge qspi_itf.sck or posedge qspi_cs_itf.csn);

          if (qspi_cs_itf.csn == 1'b0) begin
            dpi_qspim_sck_edge(dpi_handle, $realtime*1000, qspi_itf.sck,
              qspi_itf.data_0_in, qspi_itf.data_1_in, qspi_itf.data_2_in,
              qspi_itf.data_2_in
            );
          end

        end while (qspi_cs_itf.csn == 1'b0);

        dpi_qspim_cs_edge(dpi_handle, $realtime*1000, qspi_cs_itf.csn);

      end while(1);
      join_none
    endtask

    task toggle () ;
      do begin
      end while(1);
    endtask


  endclass

endpackage
