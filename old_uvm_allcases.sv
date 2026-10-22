import uvm_pkg::*;
`include "uvm_macros.svh"

// ── 1. Transaction ──────────────────────────────────────────────
class matrix_seq_item extends uvm_sequence_item;
    `uvm_object_utils(matrix_seq_item)

    rand bit [7:0]  a [0:1][0:1];
    rand bit [7:0]  b [0:1][0:1];
    bit [15:0] exp_c [0:1][0:1];   // from Python golden model
    bit [15:0] act_c [0:1][0:1];   // filled in by monitor

    function new(string name = "matrix_seq_item");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf("A=[%0d,%0d;%0d,%0d] B=[%0d,%0d;%0d,%0d] exp_C=[%0d,%0d;%0d,%0d]",
            a[0][0],a[0][1],a[1][0],a[1][1],
            b[0][0],b[0][1],b[1][0],b[1][1],
            exp_c[0][0],exp_c[0][1],exp_c[1][0],exp_c[1][1]);
    endfunction
endclass

// ── 2. Sequence — reads vectors.txt written by Python ───────────
class matrix_vector_seq extends uvm_sequence #(matrix_seq_item);
    `uvm_object_utils(matrix_vector_seq)

    function new(string name = "matrix_vector_seq");
        super.new(name);
    endfunction

    task body();
        integer fd, code;
        int a00,a01,a10,a11,b00,b01,b10,b11,c00,c01,c10,c11;
        matrix_seq_item item;

        fd = $fopen("vectors.txt", "r");
        if (fd == 0)
            `uvm_fatal("SEQ", "Could not open vectors.txt — make sure it is uploaded alongside your testbench files")

        while (!$feof(fd)) begin
            code = $fscanf(fd, "%d %d %d %d %d %d %d %d %d %d %d %d",
                            a00,a01,a10,a11,b00,b01,b10,b11,c00,c01,c10,c11);
            if (code != 12) continue;  // skip blank/trailing lines

            item = matrix_seq_item::type_id::create("item");
            start_item(item);
            item.a[0][0]=a00; item.a[0][1]=a01;
            item.a[1][0]=a10; item.a[1][1]=a11;
            item.b[0][0]=b00; item.b[0][1]=b01;
            item.b[1][0]=b10; item.b[1][1]=b11;
            item.exp_c[0][0]=c00; item.exp_c[0][1]=c01;
            item.exp_c[1][0]=c10; item.exp_c[1][1]=c11;
            finish_item(item);
        end
        $fclose(fd);
    endtask
endclass

// ── 3. Driver ────────────────────────────────────────────────────
class matrix_driver extends uvm_driver #(matrix_seq_item);
    `uvm_component_utils(matrix_driver)

    virtual matrix_if vif;
    uvm_analysis_port #(matrix_seq_item) drv_ap;  // publishes "expected" side to scoreboard

    function new(string name, uvm_component parent);
        super.new(name, parent);
        drv_ap = new("drv_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual matrix_if)::get(this, "", "vif", vif))
            `uvm_fatal("DRV", "No vif found in config_db")
    endfunction

    task run_phase(uvm_phase phase);
        matrix_seq_item item;

        vif.rst <= 1;
        repeat(2) @(posedge vif.clk);
        vif.rst <= 0;
        @(posedge vif.clk);

        forever begin
            seq_item_port.get_next_item(item);

            @(posedge vif.clk);
            vif.A <= item.a;
            vif.B <= item.b;

            @(posedge vif.clk);
            wait (vif.done == 1);

            drv_ap.write(item);   // send expected value to scoreboard
            seq_item_port.item_done();
        end
    endtask
endclass

// ── 4. Monitor ───────────────────────────────────────────────────
class matrix_monitor extends uvm_monitor;
    `uvm_component_utils(matrix_monitor)

    virtual matrix_if vif;
    uvm_analysis_port #(matrix_seq_item) mon_ap;  // publishes "actual" side to scoreboard

    function new(string name, uvm_component parent);
        super.new(name, parent);
        mon_ap = new("mon_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual matrix_if)::get(this, "", "vif", vif))
            `uvm_fatal("MON", "No vif found in config_db")
    endfunction

    task run_phase(uvm_phase phase);
        matrix_seq_item item;
        forever begin
            @(posedge vif.clk);
            if (vif.done) begin
                item = matrix_seq_item::type_id::create("mon_item");
                item.act_c = vif.C;
                mon_ap.write(item);
            end
        end
    endtask
endclass

// ── 5. Scoreboard — compares Python's expected C vs hardware's actual C ──
class matrix_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(matrix_scoreboard)

    uvm_tlm_analysis_fifo #(matrix_seq_item) exp_fifo;
    uvm_tlm_analysis_fifo #(matrix_seq_item) act_fifo;
    int pass_cnt = 0;
    int fail_cnt = 0;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        exp_fifo = new("exp_fifo", this);
        act_fifo = new("act_fifo", this);
    endfunction

    task run_phase(uvm_phase phase);
        matrix_seq_item exp_item, act_item;
        forever begin
            exp_fifo.get(exp_item);
            act_fifo.get(act_item);

            if (exp_item.exp_c[0][0] === act_item.act_c[0][0] &&
                exp_item.exp_c[0][1] === act_item.act_c[0][1] &&
                exp_item.exp_c[1][0] === act_item.act_c[1][0] &&
                exp_item.exp_c[1][1] === act_item.act_c[1][1]) begin
                pass_cnt++;
                `uvm_info("SB", $sformatf("PASS: %s", exp_item.convert2string()), UVM_LOW)
            end else begin
                fail_cnt++;
                `uvm_error("SB", $sformatf("FAIL: %s | actual_C=[%0d,%0d;%0d,%0d]",
                    exp_item.convert2string(),
                    act_item.act_c[0][0],act_item.act_c[0][1],
                    act_item.act_c[1][0],act_item.act_c[1][1]))
            end
        end
    endtask

    function void report_phase(uvm_phase phase);
        `uvm_info("SB", $sformatf("TOTAL RESULT: %0d PASS, %0d FAIL", pass_cnt, fail_cnt), UVM_LOW)
    endfunction
endclass

// ── 6. Agent ─────────────────────────────────────────────────────
class matrix_agent extends uvm_agent;
    `uvm_component_utils(matrix_agent)

    matrix_driver driver;
    matrix_monitor monitor;
    uvm_sequencer #(matrix_seq_item) sequencer;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        driver    = matrix_driver::type_id::create("driver", this);
        monitor   = matrix_monitor::type_id::create("monitor", this);
        sequencer = uvm_sequencer#(matrix_seq_item)::type_id::create("sequencer", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction
endclass

// ── 7. Environment ───────────────────────────────────────────────
class matrix_env extends uvm_env;
    `uvm_component_utils(matrix_env)

    matrix_agent agent;
    matrix_scoreboard sb;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent = matrix_agent::type_id::create("agent", this);
        sb    = matrix_scoreboard::type_id::create("sb", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agent.driver.drv_ap.connect(sb.exp_fifo.analysis_export);
        agent.monitor.mon_ap.connect(sb.act_fifo.analysis_export);
    endfunction
endclass

// ── 8. Test ──────────────────────────────────────────────────────
class matrix_test extends uvm_test;
    `uvm_component_utils(matrix_test)

    matrix_env env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = matrix_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        matrix_vector_seq seq;
        phase.raise_objection(this);
        seq = matrix_vector_seq::type_id::create("seq");
        seq.start(env.agent.sequencer);
        #20;
        phase.drop_objection(this);
    endtask
endclass 
