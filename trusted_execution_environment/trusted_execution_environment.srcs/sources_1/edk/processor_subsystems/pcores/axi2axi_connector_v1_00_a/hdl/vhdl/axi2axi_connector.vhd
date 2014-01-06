-------------------------------------------------------------------------------
---- (c) Copyright 2010 Xilinx, Inc. All rights reserved.
----
---- This file contains confidential and proprietary information
---- of Xilinx, Inc. and is protected under U.S. and
---- international copyright and other intellectual property
---- laws.
----
---- DISCLAIMER
---- This disclaimer is not a license and does not grant any
---- rights to the materials distributed herewith. Except as
---- otherwise provided in a valid license issued to you by
---- Xilinx, and to the maximum extent permitted by applicable
---- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
---- WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
---- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
---- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
---- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
---- (2) Xilinx shall not be liable (whether in contract or tort,
---- including negligence, or under any other theory of
---- liability) for any loss or damage of any kind or nature
---- related to, arising under or in connection with these
---- materials, including for any direct, or any indirect,
---- special, incidental, or consequential loss or damage
---- (including loss of data, profits, goodwill, or any type of
---- loss or damage suffered as a result of any action brought
---- by a third party) even if such damage or loss was
---- reasonably foreseeable or Xilinx had been advised of the
---- possibility of the same.
----
---- CRITICAL APPLICATIONS
---- Xilinx products are not designed or intended to be fail-
---- safe, or for use in any application requiring fail-safe
---- performance, such as life-support or safety devices or
---- systems, Class III medical devices, nuclear facilities,
---- applications related to the deployment of airbags, or any
---- other applications that could lead to death, personal
---- injury, or severe property or environmental damage
---- (individually and collectively, "Critical
---- Applications"). Customer assumes the sole risk and
---- liability of any use of Xilinx products in Critical
---- Applications, subject only to applicable laws and
---- regulations governing limitations on product liability.
----
---- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
---- PART OF THIS FILE AT ALL TIMES.
-------------------------------------------------------------------------------
--
-- AXI-to-AXI Connector
--   Wire pass-through; no logic
--
-- Verilog-standard:  Verilog 2001
----------------------------------------------------------------------------
--
-- Structure:
--   axi2axi_connector
--
----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library proc_common_v3_00_a;
use proc_common_v3_00_a.proc_common_pkg.all;
use proc_common_v3_00_a.ipif_pkg.all;

entity  axi2axi_connector is
  generic
  (
    -- ADD USER GENERICS BELOW THIS LINE ---------------
    --USER generics added here
    -- ADD USER GENERICS ABOVE THIS LINE ---------------

    -- DO NOT EDIT BELOW THIS LINE ---------------------
    -- Bus protocol parameters, do not add to or delete
    C_S_AXI_ID_WIDTH : integer :=  1;
    C_S_AXI_ADDR_WIDTH : integer :=  32;
    C_S_AXI_DATA_WIDTH : integer :=  32;
    C_S_AXI_AWUSER_WIDTH : integer :=  1;
    C_S_AXI_ARUSER_WIDTH : integer :=  1;
    C_S_AXI_WUSER_WIDTH : integer :=  1;
    C_S_AXI_RUSER_WIDTH : integer :=  1;
    C_S_AXI_BUSER_WIDTH : integer :=  1--;
    -- DO NOT EDIT ABOVE THIS LINE ---------------------
  );
  port
  (
    -- ADD USER PORTS BELOW THIS LINE ------------------
    -- USER ports added here
    -- ADD USER PORTS ABOVE THIS LINE ------------------

    -- DO NOT EDIT BELOW THIS LINE ---------------------

    -- System Signals
    ACLK : in std_logic;
    ARESETN : in std_logic;

    -- Slave Interface Write Address Ports
    S_AXI_AWID : in std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
    S_AXI_AWADDR : in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    S_AXI_AWLEN : in std_logic_vector(8-1 downto 0);
    S_AXI_AWSIZE : in std_logic_vector(3-1 downto 0);
    S_AXI_AWBURST : in std_logic_vector(2-1 downto 0);
    S_AXI_AWLOCK : in std_logic_vector(2-1 downto 0);
    S_AXI_AWCACHE : in std_logic_vector(4-1 downto 0);
    S_AXI_AWPROT : in std_logic_vector(3-1 downto 0);
    S_AXI_AWREGION : in std_logic_vector(4-1 downto 0);
    S_AXI_AWQOS : in std_logic_vector(4-1 downto 0);
    S_AXI_AWUSER : in std_logic_vector(C_S_AXI_AWUSER_WIDTH-1 downto 0);
    S_AXI_AWVALID : in std_logic;
    S_AXI_AWREADY : out std_logic;

    -- Slave Interface Write Data Ports
    S_AXI_WID : in std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
    S_AXI_WDATA : in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    S_AXI_WSTRB : in std_logic_vector(C_S_AXI_DATA_WIDTH/8-1 downto 0);
    S_AXI_WLAST : in std_logic;
    S_AXI_WUSER : in std_logic_vector(C_S_AXI_WUSER_WIDTH-1 downto 0);
    S_AXI_WVALID : in std_logic;
    S_AXI_WREADY : out std_logic;

    -- Slave Interface Write Response Ports
    S_AXI_BID : out std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
    S_AXI_BRESP : out std_logic_vector(2-1 downto 0);
    S_AXI_BUSER : out std_logic_vector(C_S_AXI_BUSER_WIDTH-1 downto 0);
    S_AXI_BVALID : out std_logic;
    S_AXI_BREADY : in std_logic;

    -- Slave Interface Read Address Ports
    S_AXI_ARID : in std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
    S_AXI_ARADDR : in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    S_AXI_ARLEN : in std_logic_vector(8-1 downto 0);
    S_AXI_ARSIZE : in std_logic_vector(3-1 downto 0);
    S_AXI_ARBURST : in std_logic_vector(2-1 downto 0);
    S_AXI_ARLOCK : in std_logic_vector(2-1 downto 0);
    S_AXI_ARCACHE : in std_logic_vector(4-1 downto 0);
    S_AXI_ARPROT : in std_logic_vector(3-1 downto 0);
    S_AXI_ARREGION : in std_logic_vector(4-1 downto 0);
    S_AXI_ARQOS : in std_logic_vector(4-1 downto 0);
    S_AXI_ARUSER : in std_logic_vector(C_S_AXI_ARUSER_WIDTH-1 downto 0);
    S_AXI_ARVALID : in std_logic;
    S_AXI_ARREADY : out std_logic;

    -- Slave Interface Read Data Ports
    S_AXI_RID : out std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
    S_AXI_RDATA : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    S_AXI_RRESP : out std_logic_vector(2-1 downto 0);
    S_AXI_RLAST : out std_logic;
    S_AXI_RUSER : out std_logic_vector(C_S_AXI_RUSER_WIDTH-1 downto 0);
    S_AXI_RVALID : out std_logic;
    S_AXI_RREADY : in std_logic;
    
    -- Master Interface Write Address Port
    M_AXI_AWID : out std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
    M_AXI_AWADDR : out std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    M_AXI_AWLEN : out std_logic_vector(8-1 downto 0);
    M_AXI_AWSIZE : out std_logic_vector(3-1 downto 0);
    M_AXI_AWBURST : out std_logic_vector(2-1 downto 0);
    M_AXI_AWLOCK : out std_logic_vector(2-1 downto 0);
    M_AXI_AWCACHE : out std_logic_vector(4-1 downto 0);
    M_AXI_AWPROT : out std_logic_vector(3-1 downto 0);
-- axi_interconnect doesn't use this
--    M_AXI_AWREGION : out std_logic_vector(4-1 downto 0);
    M_AXI_AWQOS : out std_logic_vector(4-1 downto 0);
    M_AXI_AWUSER : out std_logic_vector(C_S_AXI_AWUSER_WIDTH-1 downto 0);
    M_AXI_AWVALID : out std_logic;
    M_AXI_AWREADY : in std_logic;
    
    -- Master Interface Write Data Ports
    M_AXI_WID : out std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
    M_AXI_WDATA : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    M_AXI_WSTRB : out std_logic_vector(C_S_AXI_DATA_WIDTH/8-1 downto 0);
    M_AXI_WLAST : out std_logic;
    M_AXI_WUSER : out std_logic_vector(C_S_AXI_WUSER_WIDTH-1 downto 0);
    M_AXI_WVALID : out std_logic;
    M_AXI_WREADY : in std_logic;
    
    -- Master Interface Write Response Ports
    M_AXI_BID : in std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
    M_AXI_BRESP : in std_logic_vector(2-1 downto 0);
    M_AXI_BUSER : in std_logic_vector(C_S_AXI_BUSER_WIDTH-1 downto 0);
    M_AXI_BVALID : in std_logic;
    M_AXI_BREADY : out std_logic;
    
    -- Master Interface Read Address Port
    M_AXI_ARID : out std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
    M_AXI_ARADDR : out std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    M_AXI_ARLEN : out std_logic_vector(8-1 downto 0);
    M_AXI_ARSIZE : out std_logic_vector(3-1 downto 0);
    M_AXI_ARBURST : out std_logic_vector(2-1 downto 0);
    M_AXI_ARLOCK : out std_logic_vector(2-1 downto 0);
    M_AXI_ARCACHE : out std_logic_vector(4-1 downto 0);
    M_AXI_ARPROT : out std_logic_vector(3-1 downto 0);
-- axi_interconnect doesn't use this
--    M_AXI_ARREGION : out std_logic_vector(4-1 downto 0);
    M_AXI_ARQOS : out std_logic_vector(4-1 downto 0);
    M_AXI_ARUSER : out std_logic_vector(C_S_AXI_ARUSER_WIDTH-1 downto 0);
    M_AXI_ARVALID : out std_logic;
    M_AXI_ARREADY : in std_logic;
    
    -- Master Interface Read Data Ports
    M_AXI_RID : in std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
    M_AXI_RDATA : in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    M_AXI_RRESP : in std_logic_vector(2-1 downto 0);
    M_AXI_RLAST : in std_logic;
    M_AXI_RUSER : in std_logic_vector(C_S_AXI_RUSER_WIDTH-1 downto 0);
    M_AXI_RVALID : in std_logic;
    M_AXI_RREADY : out std_logic--;
    -- DO NOT EDIT ABOVE THIS LINE ---------------------
  );
end entity axi2axi_connector;

------------------------------------------------------------------------------
-- Architecture section
------------------------------------------------------------------------------

architecture IMP of axi2axi_connector is

begin

  -- Write address port
  M_AXI_AWID <= S_AXI_AWID;
  M_AXI_AWADDR <= S_AXI_AWADDR;
  M_AXI_AWLEN <= S_AXI_AWLEN;
  M_AXI_AWSIZE <= S_AXI_AWSIZE;
  M_AXI_AWBURST <= S_AXI_AWBURST;
  M_AXI_AWLOCK <= S_AXI_AWLOCK;
  M_AXI_AWCACHE <= S_AXI_AWCACHE;
  M_AXI_AWPROT <= S_AXI_AWPROT;
-- axi_interconnect doesn't use this
--  M_AXI_AWREGION <= S_AXI_AWREGION;
  M_AXI_AWQOS <= S_AXI_AWQOS;
  M_AXI_AWUSER <= S_AXI_AWUSER;
  M_AXI_AWVALID <= S_AXI_AWVALID;
  S_AXI_AWREADY <= M_AXI_AWREADY;

  -- Write Data Port
  M_AXI_WID <= S_AXI_WID;
  M_AXI_WDATA <= S_AXI_WDATA;
  M_AXI_WSTRB <= S_AXI_WSTRB;
  M_AXI_WLAST <= S_AXI_WLAST;
  M_AXI_WUSER <= S_AXI_WUSER;
  M_AXI_WVALID <= S_AXI_WVALID;
  S_AXI_WREADY <= M_AXI_WREADY;

  -- Write Response Port
  S_AXI_BID <= M_AXI_BID;
  S_AXI_BRESP <= M_AXI_BRESP;
  S_AXI_BUSER <= M_AXI_BUSER;
  S_AXI_BVALID <= M_AXI_BVALID;
  M_AXI_BREADY <= S_AXI_BREADY;
  
  -- Read Address Port
  M_AXI_ARID <= S_AXI_ARID;
  M_AXI_ARADDR <= S_AXI_ARADDR;
  M_AXI_ARLEN <= S_AXI_ARLEN;
  M_AXI_ARSIZE <= S_AXI_ARSIZE;
  M_AXI_ARBURST <= S_AXI_ARBURST;
  M_AXI_ARLOCK <= S_AXI_ARLOCK;
  M_AXI_ARCACHE <= S_AXI_ARCACHE;
  M_AXI_ARPROT <= S_AXI_ARPROT;
-- axi_interconnect doesn't use this
--  M_AXI_ARREGION <= S_AXI_ARREGION;
  M_AXI_ARQOS <= S_AXI_ARQOS;
  M_AXI_ARUSER <= S_AXI_ARUSER;
  M_AXI_ARVALID <= S_AXI_ARVALID;
  S_AXI_ARREADY <= M_AXI_ARREADY;

  -- Read Data Port
  S_AXI_RID <= M_AXI_RID;
  S_AXI_RDATA <= M_AXI_RDATA;
  S_AXI_RRESP <= M_AXI_RRESP;
  S_AXI_RLAST <= M_AXI_RLAST;
  S_AXI_RUSER <= M_AXI_RUSER;
  S_AXI_RVALID <= M_AXI_RVALID;
  M_AXI_RREADY <= S_AXI_RREADY;

end IMP;
