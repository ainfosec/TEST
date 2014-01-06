TEST
====

Trusted Enclave Sandbox and Toolkit

TEST is a simple Trusted Execution Environment (TEE) implementation.
 It was designed for Xilinx EDK v14.7 and the Digilent ZedBoard
 which contains a Cortex A9 MPCore processor. The software driver
 files and the hardware pcore edkregfile rely on this configuration;
 other parts of TEST are largely hardware and toolchain agnostic
 and should be adaptable to other platforms.

All content within is owned by Assured Information Security and
 is (c) 2013 AIS, all rights reserved.
ARM TrustZone, ARM Thumb, and Cortex A9 MPCore are registered
 trademarks of ARM Holdings plc.
The ZedBoard is a modification of the Xilinx Zynq development
 platform and is manufactured and distributed by Digilent inc.

EDK, PlanAhead, XPS, and XDK are registered trademarks of Xilinx
 inc.

TEST is a forward-engineered TEE which can be reconfigured to
 mimic the functionality of other trusted enclave implementations.
 One such configuration closely matches ARM TrustZone, and is
 included with TEST. TEST does not, however, contain an ARM coprocessor.
 Therefore, while TEST could in theory be used to develop a program
 similar to ARM's "Hello World for TrustZone",
 http://infocenter.arm.com/help/index.jsp?topic=/com.arm.doc.faqs/ka15417.html
 , the program will only be theoritically similar and will not
 actually run on a TrustZone enabled ARM SoC.

TEST was created in order to have a fully documented TEE system
 distributed by a single vendor. In industry,
 a system incorporating a solution like TrustZone may have the
 processor specification, processor implementation, System-on-a-Chip
 (SoC) implementation, and Engineering Development Kit (EDK)
 containing board support packages and drivers, all developed
 and distributed by different vendors. This can create frustrating
 holes in documentation, and technologies that rely on completely
 undocumented features. Even if the processor and underlying
 technologies are fully documented, for instance, the people
 developing that documentation do not know which specific pins
 or register identifiers are going to be chosen in the final
 SoC.

TEST is capable of Assymetric and Symmetric Multi-Processing
 (AMP and SMP, respectively), and the TrustZone profile contains
 functionality analagous to all of TrustZone's control bits.
 It contains a soft processor which is completely platform independent,
 which relies on a pure software instruction stack. This creates
 a software-friendly platform which can be used to explore both
 attacking and defending sandboxing solutions, TEEs, and similar
 solutions.
