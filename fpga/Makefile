PROJECT ?= MP

RTL_SRC := $(PWD)/../hw/src/MP_LUT_top.sv
XDC_SRC := $(PWD)/../constraint/timing.xdc \
		   $(PWD)/../constraint/physical.xdc

PARAM := M=3 K=7 RESOLUTION=4096

FPGA_PART = xcvc1902-vsva2197-2MP-e-S

.PHONY: all create synth impl report bit clean

all: create synth impl report pdi

create: $(PROJECT).xpr

synth: $(PROJECT).runs/synth_1/$(PROJECT).dcp

impl: $(PROJECT).runs/impl_1/$(PROJECT)_routed.dcp

report: $(PROJECT)_utilization.rpt

pdi: $(PROJECT).pdi

create_project.tcl: $(RTL_SRC) $(XDC_SRC)
	echo "create_project -force -part $(FPGA_PART) $(PROJECT)" > $@
	echo "add_files -fileset sources_1 $(RTL_SRC)" >> $@
	echo "add_files -fileset constrs_1 $(XDC_SRC)" >> $@

config_param.tcl:
	for x in $(PARAM); do echo 'set_property generic {' $$x '} [current_fileset]'>> $@; done

run_synth.tcl: $(PROJECT).xpr
	echo "open_project $(PROJECT).xpr" > $@
	echo "reset_run synth_1" >> $@
	echo "launch_runs -jobs `nproc` synth_1" >> $@
	echo "wait_on_run synth_1" >> $@

run_impl.tcl: $(PROJECT).runs/synth_1/$(PROJECT).dcp
	echo "open_project $(PROJECT).xpr" > $@
	echo "reset_run impl_1" >> $@
	echo "launch_runs -jobs 3 impl_1" >> $@
	echo "wait_on_run impl_1" >> $@

run_report.tcl: $(PROJECT).runs/impl_1/$(PROJECT)_routed.dcp
	echo "open_project $(PROJECT).xpr" > $@
	echo "open_run impl_1" >> $@
	echo "report_utilization -file $(PROJECT)_utilization.rpt" >> $@
	echo "report_utilization -hierarchical -file $(PROJECT)_utilization_hierarchical.rpt" >> $@
	echo "report_timing_summary -file $(PROJECT)_timing.rpt" >> $@

run_pdi.tcl: $(PROJECT).runs/impl_1/$(PROJECT)_routed.dcp
	echo "open_project $(PROJECT).xpr" > $@
	echo "open_run impl_1" >> $@
	echo "write_device_image -force $(PROJECT).runs/impl_1/$(PROJECT).pdi" >> $@

# Create project
$(PROJECT).xpr: create_project.tcl config_param.tcl
	vivado -nojournal -nolog -mode batch $(foreach x,$?,-source $x)

# Synthesis
$(PROJECT).runs/synth_1/$(PROJECT).dcp: run_synth.tcl
	vivado -nojournal -nolog -mode batch -source $?

# Implementation
$(PROJECT).runs/impl_1/$(PROJECT)_routed.dcp: run_impl.tcl
	vivado -nojournal -nolog -mode batch -source $?

# Report
$(PROJECT)_utilization.rpt: run_report.tcl
	vivado -nojournal -nolog -mode batch -source $?

# Bitstream
$(PROJECT).pdi: run_pdi.tcl
	vivado -nojournal -nolog -mode batch -source $?

clean:
	-rm -rf *.log *.jou *.cache *.gen *.hbs *.hw *.ip_user_files *.runs *.xpr *.html *.xml *.sim *.srcs *.str .Xil
	-rm -rf create_project.tcl config_param.tcl run_synth.tcl run_impl.tcl run_report.tcl run_pdi.tcl
	-rm -rf *.pdi *.ltx program.tcl generate_mcs.tcl *.mcs *.prm flash.tcl
	-rm -rf *_utilization.rpt *_utilization_hierarchical.rpt *_timing.rpt
	-rm -rf rev
