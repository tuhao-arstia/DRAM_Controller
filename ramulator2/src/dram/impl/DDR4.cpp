#include "base/request.h"
#include "dram/dram.h"
#include "dram/lambdas.h"
#include <iostream>

namespace Ramulator {

class DDR4 : public IDRAM, public Implementation {
  RAMULATOR_REGISTER_IMPLEMENTATION(IDRAM, DDR4, "DDR4", "DDR4 Device Model")

  double m_activation_power = 0;
  double m_precharge_power = 0;
  double m_read_power = 0;
  double m_write_power = 0;
  double m_refresh_power = 0;

  public:
    inline static const std::map<std::string, Organization> org_presets = {
      //   name         density   DQ  Ch Ra  Bg Ba  Ro     Co
      {"DDR4_2Gb_x4",   {2<<10,   4,  {1, 1, 4, 4, 1<<15, 1<<10}}},
      {"DDR4_2Gb_x8",   {2<<10,   8,  {1, 1, 4, 4, 1<<14, 1<<10}}},
      {"DDR4_2Gb_x16",  {2<<10,   16, {1, 1, 2, 4, 1<<14, 1<<10}}},
      {"DDR4_4Gb_x4",   {4<<10,   4,  {1, 1, 4, 4, 1<<16, 1<<10}}},
      {"DDR4_4Gb_x8",   {4<<10,   8,  {1, 1, 4, 4, 1<<15, 1<<10}}},
      {"DDR4_4Gb_x16",  {4<<10,   16, {1, 1, 2, 4, 1<<15, 1<<10}}},
      {"DDR4_8Gb_x4",   {8<<10,   4,  {1, 1, 4, 4, 1<<17, 1<<10}}},
      {"DDR4_8Gb_x8",   {8<<10,   8,  {1, 1, 4, 4, 1<<16, 1<<10}}},
      {"DDR4_8Gb_x16",  {8<<10,   16, {1, 1, 2, 4, 1<<16, 1<<10}}},
      {"DDR4_16Gb_x4",  {16<<10,  4,  {1, 1, 4, 4, 1<<18, 1<<10}}},
      {"DDR4_16Gb_x8",  {16<<10,  8,  {1, 1, 4, 4, 1<<17, 1<<10}}},
      {"DDR4_16Gb_x16", {16<<10,  16, {1, 1, 2, 4, 1<<17, 1<<10}}},
      // Senior's model a 1Gb x 128 based on DDR3 DDR3_1600J timings model
      // research the meaning of these , density and dq, the statistics are strange
      //         name                  density     DQ             Ch      Ra     Bg    Ba        Ro       Co(Page size)
      {"DDR4_4Gb_4banks_x1024",  {4<<10, 1024, {1, 1, 1, 4, 1 << 16, 1 << 4}}},
      {"DDR4_1Gb_1bank_x1024" ,  {1<<10, 1024, {1, 1, 1, 1, 1 << 16, 1 << 4}}},
      //
      // Senior's model a 4Gb x 128 based on DDR3 DDR3_1600J timings model, dq means how many bit stored within each column
      // name                           density   DQ                Ch    Ra      Bg   Ba          Ro     Co(Page size)
      // Definitely something wrong here
      {"DDR4_256Mb_x4_x128",{1 << 8, 128, {1,  1, 1, 1, 1 << 13, 1 << 8}}},
      // name                           density   DQ                Ch    Ra      Bg   Ba          Ro     Co(Page size)
      {"DDR4_256Mb_x1_x128",{1 << 8, 128, {1,  1, 1, 1, 1 << 13, 1 << 8}}},
      //
    };

    inline static const std::map<std::string, std::vector<int>> timing_presets = {
      //   name          rate   nBL  nCL nRCD  nRP   nRAS   nRC  nWR     nRTP      nCWL  nCCDS nCCDL nRRDS nRRDL nWTRS nWTRL nFAW  nRFC nREFI nCS,  tCK_ps
      {"DDR4_1600J",    {1600,   4,  10,  10,   10,   28,   38,   12,   6,   9,    4,    5,   -1,   -1,    2,    6,   -1,  -1,  -1,   2,    1250}},
      {"DDR4_1600K",    {1600,   4,  11,  11,   11,   28,   39,   12,   6,   9,    4,    5,   -1,   -1,    2,    6,   -1,  -1,  -1,   2,    1250}},
      {"DDR4_1600L",    {1600,   4,  12,  12,   12,   28,   40,   12,   6,   9,    4,    5,   -1,   -1,    2,    6,   -1,  -1,  -1,   2,    1250}},
      {"DDR4_1866L",    {1866,   4,  12,  12,   12,   32,   44,   14,   7,   10,   4,    5,   -1,   -1,    3,    7,   -1,  -1,  -1,   2,    1071}},
      {"DDR4_1866M",    {1866,   4,  13,  13,   13,   32,   45,   14,   7,   10,   4,    5,   -1,   -1,    3,    7,   -1,  -1,  -1,   2,    1071}},
      {"DDR4_1866N",    {1866,   4,  14,  14,   14,   32,   46,   14,   7,   10,   4,    5,   -1,   -1,    3,    7,   -1,  -1,  -1,   2,    1071}},
      {"DDR4_2133N",    {2133,   4,  14,  14,   14,   36,   50,   16,   8,   11,   4,    6,   -1,   -1,    3,    8,   -1,  -1,  -1,   2,    937} },
      {"DDR4_2133P",    {2133,   4,  15,  15,   15,   36,   51,   16,   8,   11,   4,    6,   -1,   -1,    3,    8,   -1,  -1,  -1,   2,    937} },
      {"DDR4_2133R",    {2133,   4,  16,  16,   16,   36,   52,   16,   8,   11,   4,    6,   -1,   -1,    3,    8,   -1,  -1,  -1,   2,    937} },
      {"DDR4_2400P",    {2400,   4,  15,  15,   15,   39,   54,   18,   9,   12,   4,    6,   -1,   -1,    3,    9,   -1,  -1,  -1,   2,    833} },
      {"DDR4_2400R",    {2400,   4,  16,  16,   16,   39,   55,   18,   9,   12,   4,    6,   -1,   -1,    3,    9,   -1,  -1,  -1,   2,    833} },
      {"DDR4_2400U",    {2400,   4,  17,  17,   17,   39,   56,   18,   9,   12,   4,    6,   -1,   -1,    3,    9,   -1,  -1,  -1,   2,    833} },
      {"DDR4_2400T",    {2400,   4,  18,  18,   18,   39,   57,   18,   9,   12,   4,    6,   -1,   -1,    3,    9,   -1,  -1,  -1,   2,    833} },
      {"DDR4_2666T",    {2666,   4,  17,  17,   17,   43,   60,   20,   10,  14,   4,    7,   -1,   -1,    4,    10,  -1,  -1,  -1,   2,    750} },
      {"DDR4_2666U",    {2666,   4,  18,  18,   18,   43,   61,   20,   10,  14,   4,    7,   -1,   -1,    4,    10,  -1,  -1,  -1,   2,    750} },
      {"DDR4_2666V",    {2666,   4,  19,  19,   19,   43,   62,   20,   10,  14,   4,    7,   -1,   -1,    4,    10,  -1,  -1,  -1,   2,    750} },
      {"DDR4_2666W",    {2666,   4,  20,  20,   20,   43,   63,   20,   10,  14,   4,    7,   -1,   -1,    4,    10,  -1,  -1,  -1,   2,    750} },
      {"DDR4_2933V",    {2933,   4,  19,  19,   19,   47,   66,   22,   11,  16,   4,    8,   -1,   -1,    4,    11,  -1,  -1,  -1,   2,    682} },
      {"DDR4_2933W",    {2933,   4,  20,  20,   20,   47,   67,   22,   11,  16,   4,    8,   -1,   -1,    4,    11,  -1,  -1,  -1,   2,    682} },
      {"DDR4_2933Y",    {2933,   4,  21,  21,   21,   47,   68,   22,   11,  16,   4,    8,   -1,   -1,    4,    11,  -1,  -1,  -1,   2,    682} },
      {"DDR4_2933AA",   {2933,   4,  22,  22,   22,   47,   69,   22,   11,  16,   4,    8,   -1,   -1,    4,    11,  -1,  -1,  -1,   2,    682} },
      {"DDR4_3200W",    {3200,   4,  20,  20,   20,   52,   72,   24,   12,  16,   4,    8,   -1,   -1,    4,    12,  -1,  -1,  -1,   2,    625} },
      {"DDR4_3200AA",   {3200,   4,  22,  22,   22,   52,   74,   24,   12,  16,   4,    8,   -1,   -1,    4,    12,  -1,  -1,  -1,   2,    625} },
      {"DDR4_3200AC",   {3200,   4,  24,  24,   24,   52,   76,   24,   12,  16,   4,    8,   -1,   -1,    4,    12,  -1,  -1,  -1,   2,    625} },

      //t_CAS, (CACTI3DD 3.783(ns))	   t_RAS	    t_RC	  t_RCD	    t_RP	  t_RRD
      // 4                     , 17      , 23      , 11      , 7      , 3
      //         name        rate                nBL                      nCL                    nRCD                       nRP               nRAS                 nRC            nWR          nRTP          nCWL(TSV as IO)    nCCDS nCCDL nRRDS nRRDL nWTRS nWTRL nFAW  nRFC nREFI nCS,  tCK_ps
      {"DDR4_3DDRAM_1024",  {1600,                1,                       14,                    11,                         7,                17,                  23,           9,            8,                14,             3,    3,   -1,    -1,   2,     4,  -1,   -1,   -1,  2,   1000}},

      //t_CAS	   t_RAS	    t_RC	  t_RCD	    t_RP	  t_RRD
      // 8	 "	"	14	 "	"	16	 "	"	13	 "	"	4	 "	"	2	 "
      //            name                rate              nBL            nCL            nRCD          nRP        nRAS            nRC         nWR           nRTP          nCWL  nCCDS nCCDL nRRDS nRRDL nWTRS nWTRL nFAW  nRFC nREFI nCS,  tCK_ps
      {"DDR4_3DDRAM_128",{       1600,                    1,              6,             13,          4,         14,              16,      12,       6,          9,   1,    2,   -1,    -1,   2,     4,    -1,   -1,   -1,    2,    1250}},
                        //rate    nBL  nCL  nRCD  nRP   nRAS  nRC   nWR  nRTP nCWL nCCD  nRRD  nWTR  nFAW  nRFC nREFI  nCS  tCK_ps
      // The unit is number of tCK_ps, it is 1250 here
      {"DDR4_3DDRAM_512",{1600,   4,   10,   5,   10,    8,   12,   12,    6,   9,   4,  5,   -1,    -1,   2,     6,  -1,   -1,   -1, 2,    1250}}
    };

    inline static const std::map<std::string, std::vector<double>> voltage_presets = {
      //   name               VDD      VPP
      {"Default",             {1.2,     2.5}},
      //   name               VDD      VPP
      {"3D-DRAM-32nm",       {1.0,     1.5}},
    };

    inline static const std::map<std::string, std::vector<double>> current_presets = {
      // name                 IDD0        IDD2N       IDD3N       IDD4R       IDD4W       IDD5B       IPP0      IPP2N  IPP3N  IPP4R  IPP4W  IPP5B
      {"Default",             {60,          50,         55,         145,      145,        362,          3,        3,     3,     3,     3,     48}},
    
      // name                 IDD0        IDD2N       IDD3N        IDD4R       IDD4W       IDD5B       IPP0      IPP2N  IPP3N  IPP4R  IPP4W  IPP5B
      {"3D-DRAM-32nm",        {65,          40,         55,         390,        500,        250,        65,        3,     3,     3,     3,     48}}
    };

  /************************************************
   *                Organization
   ***********************************************/
    int m_internal_prefetch_size = [](int density_Mb) -> int {
      switch (density_Mb) {
        //! only 1 is permitted
        case 256 :  return 1;
        case 1024:  return 1;
        default:    return 1;
      }
    }(m_organization.density);

    inline static constexpr ImplDef m_levels = {
      "channel", "rank", "bankgroup", "bank", "row", "column",
    };


  /************************************************
   *             Requests & Commands
   ***********************************************/
    inline static constexpr ImplDef m_commands = {
      "ACT",
      "PRE", "PREA",
      "RD",  "WR",  "RDA",  "WRA",
      "REFab", "REFab_end"
    };

    inline static const ImplLUT m_command_scopes = LUT (
      m_commands, m_levels, {
        {"ACT",   "row"},
        {"PRE",   "bank"},   {"PREA",   "rank"},
        {"RD",    "column"}, {"WR",     "column"}, {"RDA",   "column"}, {"WRA",   "column"},
        {"REFab", "rank"},  {"REFab_end", "rank"},
      }
    );

    inline static const ImplLUT m_command_meta = LUT<DRAMCommandMeta> (
      m_commands, {
                    // open?   close?   access?  refresh?
        {"ACT",       {true,   false,   false,   false}},
        {"PRE",       {false,  true,    false,   false}},
        {"PREA",      {false,  true,    false,   false}},
        {"RD",        {false,  false,   true,    false}},
        {"WR",        {false,  false,   true,    false}},
        {"RDA",       {false,  true,    true,    false}},
        {"WRA",       {false,  true,    true,    false}},
        {"REFab",     {false,  false,   false,   true }},
        {"REFab_end", {false,  true,    false,   false}},
      }
    );

    inline static constexpr ImplDef m_requests = {
      "read", "write", "all-bank-refresh", "open-row", "close-row"
    };

    inline static const ImplLUT m_request_translations = LUT (
      m_requests, m_commands, {
        {"read", "RD"}, {"write", "WR"}, {"all-bank-refresh", "REFab"},
        {"open-row", "ACT"}, {"close-row", "PRE"}
      }
    );


  /************************************************
   *                   Timing
   ***********************************************/
    inline static constexpr ImplDef m_timings = {
      "rate",
      "nBL", "nCL", "nRCD", "nRP", "nRAS", "nRC", "nWR", "nRTP", "nCWL",
      "nCCDS", "nCCDL",
      "nRRDS", "nRRDL",
      "nWTRS", "nWTRL",
      "nFAW",
      "nRFC","nREFI",
      "nCS",
      "tCK_ps"
    };


  /************************************************
   *                   Power
   ***********************************************/
    inline static constexpr ImplDef m_voltages = {
      "VDD", "VPP"
    };

    inline static constexpr ImplDef m_currents = {
      "IDD0", "IDD2N", "IDD3N", "IDD4R", "IDD4W", "IDD5B",
      "IPP0", "IPP2N", "IPP3N", "IPP4R", "IPP4W", "IPP5B"
    };

    inline static constexpr ImplDef m_cmds_counted = {
      "ACT", "PRE", "RD", "WR", "REF"
    };

  /************************************************
   *                 Node States
   ***********************************************/
    inline static constexpr ImplDef m_states = {
       "Opened", "Closed", "PowerUp", "N/A", "Refreshing"
    };

     inline static const ImplLUT m_init_states = LUT (
      m_levels, m_states, {
        {"channel",   "N/A"},
        {"rank",      "PowerUp"},
        {"bankgroup", "N/A"},
        {"bank",      "Closed"},
        {"row",       "Closed"},
        {"column",    "N/A"},
      }
    );

  public:
    struct Node : public DRAMNodeBase<DDR4> {
      Node(DDR4* dram, Node* parent, int level, int id) : DRAMNodeBase<DDR4>(dram, parent, level, id) {};
    };
    std::vector<Node*> m_channels;

    FuncMatrix<ActionFunc_t<Node>>  m_actions;
    FuncMatrix<PreqFunc_t<Node>>    m_preqs;
    FuncMatrix<RowhitFunc_t<Node>>  m_rowhits;
    FuncMatrix<RowopenFunc_t<Node>> m_rowopens;
    FuncMatrix<PowerFunc_t<Node>>   m_powers;

  public:
    void tick() override {
      m_clk++;

      // Check if there is any future action at this cycle
      for (int i = m_future_actions.size() - 1; i >= 0; i--) {
        auto& future_action = m_future_actions[i];
        if (future_action.clk == m_clk) {
          handle_future_action(future_action.cmd, future_action.addr_vec);
          m_future_actions.erase(m_future_actions.begin() + i);
        }
      }
    };

    void init() override {
      RAMULATOR_DECLARE_SPECS();
      set_organization();
      set_timing_vals();

      set_actions();
      set_preqs();
      set_rowhits();
      set_rowopens();
      set_powers();

      create_nodes();
    };

    void issue_command(int command, const AddrVec_t& addr_vec) override {
      int channel_id = addr_vec[m_levels["channel"]];
      m_channels[channel_id]->update_timing(command, addr_vec, m_clk);
      m_channels[channel_id]->update_powers(command, addr_vec, m_clk);
      m_channels[channel_id]->update_states(command, addr_vec, m_clk);

      // Check if the command requires future action
      check_future_action(command, addr_vec);
    };

    void check_future_action(int command, const AddrVec_t& addr_vec) {
      switch (command) {
        case m_commands("REFab"):
          // REFab command requires future action after nRFC cycles
          m_future_actions.push_back({command, addr_vec, m_clk + m_timing_vals("nRFC") - 1});
          break;
        default:
          // Other commands do not require future actions
          break;
      }
    }

    void handle_future_action(int command, const AddrVec_t& addr_vec) {
      int channel_id = addr_vec[m_levels["channel"]];
      switch (command) {
        case m_commands("REFab"):
          m_channels[channel_id]->update_powers(m_commands("REFab_end"), addr_vec, m_clk);
          m_channels[channel_id]->update_states(m_commands("REFab_end"), addr_vec, m_clk);
          break;
        default:
          // Other commands do not require future actions
          break;
      }
    };

    int get_preq_command(int command, const AddrVec_t& addr_vec) override {
      int channel_id = addr_vec[m_levels["channel"]];
      return m_channels[channel_id]->get_preq_command(command, addr_vec, m_clk);
    };

    bool check_ready(int command, const AddrVec_t& addr_vec) override {
      int channel_id = addr_vec[m_levels["channel"]];
      return m_channels[channel_id]->check_ready(command, addr_vec, m_clk);
    };

    bool check_rowbuffer_hit(int command, const AddrVec_t& addr_vec) override {
      int channel_id = addr_vec[m_levels["channel"]];
      return m_channels[channel_id]->check_rowbuffer_hit(command, addr_vec, m_clk);
    };

    bool check_node_open(int command, const AddrVec_t& addr_vec) override {
      int channel_id = addr_vec[m_levels["channel"]];
      return m_channels[channel_id]->check_node_open(command, addr_vec, m_clk);
    };

  private:
    void set_organization() {
      // Channel width
      m_channel_width = param_group("org").param<int>("channel_width").default_val(128);

      // Organization
      m_organization.count.resize(m_levels.size(), -1);

      // Load organization preset if provided
      if (auto preset_name = param_group("org").param<std::string>("preset").optional()) {
        if (org_presets.count(*preset_name) > 0) {
          m_organization = org_presets.at(*preset_name);
        } else {
          throw ConfigurationError("Unrecognized organization preset \"{}\" in {}!", *preset_name, get_name());
        }
      }

      // Override the preset with any provided settings
      if (auto dq = param_group("org").param<int>("dq").optional()) {
        m_organization.dq = *dq;
      }

      for (int i = 0; i < m_levels.size(); i++){
        auto level_name = m_levels(i);
        if (auto sz = param_group("org").param<int>(level_name).optional()) {
          m_organization.count[i] = *sz;
        }
      }

      if (auto density = param_group("org").param<int>("density").optional()) {
        m_organization.density = *density;
      }

      // Sanity check: is the calculated chip density the same as the provided one?
      size_t _density = size_t(m_organization.count[m_levels["bankgroup"]]) *
                        size_t(m_organization.count[m_levels["bank"]]) *
                        size_t(m_organization.count[m_levels["row"]]) *
                        size_t(m_organization.count[m_levels["column"]]) *
                        size_t(m_organization.dq);
      _density >>= 20;
      if (m_organization.density != _density) {
        throw ConfigurationError(
            "Calculated {} chip density {} Mb does not equal the provided density {} Mb!",
            get_name(),
            _density,
            m_organization.density
        );
      }
    };

    void set_timing_vals() {
      m_timing_vals.resize(m_timings.size(), -1);

      // Load timing preset if provided
      bool preset_provided = false;
      if (auto preset_name = param_group("timing").param<std::string>("preset").optional()) {
        if (timing_presets.count(*preset_name) > 0) {
          m_timing_vals = timing_presets.at(*preset_name);
          preset_provided = true;
        } else {
          throw ConfigurationError("Unrecognized timing preset \"{}\" in {}!", *preset_name, get_name());
        }
      }

      // Check for rate (in MT/s), and if provided, calculate and set tCK (in picosecond)
      if (auto dq = param_group("timing").param<int>("rate").optional()) {
        if (preset_provided) {
          throw ConfigurationError("Cannot change the transfer rate of {} when using a speed preset !", get_name());
        }
        m_timing_vals("rate") = *dq;
      }
      int tCK_ps = 1E6 / (m_timing_vals("rate") / 2);
      m_timing_vals("tCK_ps") = tCK_ps;

      // Load the organization specific timings
      int dq_id = [](int dq) -> int {
        switch (dq) {
          case 4:  return 0;
          case 8:  return 1;
          case 16: return 2;
          case 128: return 2;
          case 512: return 2;
          case 1024: return 2;
          default: return -1;
        }
      }(m_organization.dq);

      int rate_id = [](int rate) -> int {
        switch (rate) {
          case 1600:  return 0;
          case 1866:  return 1;
          case 2133:  return 2;
          case 2400:  return 3;
          case 2666:  return 4;
          case 2933:  return 5;
          case 3200:  return 6;
          default:    return -1;
        }
      }(m_timing_vals("rate"));

      // Tables for secondary timings determined by the frequency, density, and DQ width.
      // Defined in the JEDEC standard (e.g., Table 169-170, JESD79-4C).
      constexpr int nRRDS_TABLE[3][7] = {
      // 1600  1866  2133  2400  2666  2933  3200
        { 4,    4,    4,    4,    4,    4,    4},   // x4
        { 4,    4,    4,    4,    4,    4,    4},   // x8
        { 5,    5,    6,    7,    8,    8,    9},   // x16
      };
      constexpr int nRRDL_TABLE[3][7] = {
      // 1600  1866  2133  2400  2666  2933  3200
        { 5,    5,    6,    6,    7,    8,    8 },  // x4
        { 5,    5,    6,    6,    7,    8,    8 },  // x8
        { 6,    6,    7,    8,    9,    10,   11},  // x16
      };
      constexpr int nFAW_TABLE[3][7] = {
      // 1600  1866  2133  2400  2666  2933  3200
        { 16,   16,   16,   16,   16,   16,   16},  // x4
        { 20,   22,   23,   26,   28,   31,   34},  // x8
        { 28,   28,   32,   36,   40,   44,   48},  // x16
      };

      if (dq_id != -1 && rate_id != -1) {
        m_timing_vals("nRRDS") = nRRDS_TABLE[dq_id][rate_id];
        m_timing_vals("nRRDL") = nRRDL_TABLE[dq_id][rate_id];
        m_timing_vals("nFAW")  = nFAW_TABLE [dq_id][rate_id];
      }

      // Refresh timings
      // tRFC table (unit is nanosecond!), modify the DRAM timing tRFC according to the density, 
      // this should be modified according to the density of the bank 
      constexpr int tRFC_TABLE[3][6] = {
              // 256Mb   1Gb      2Gb      4Gb       8Gb       16Gb
        {         60,    110,     160,     260,      360,      550}, // Normal refresh (tRFC1)
        {         40,    80,      110,     160,      260,      350}, // FGR 2x (tRFC2)
        {         20,    60,      90,      110,      160,      260}, // FGR 4x (tRFC4)
      };

      // tREFI(base) table (unit is nanosecond!), this should be modified according to the density of the bank
      int tREFI_BASE =[](int density_Mb) -> int{
        switch (density_Mb) {
          case 256:   return 3900; //From raar, 3.9us, due to the use of 8K refresh
          case 512:   return 3900;
          case 1024:  return 3900;
          case 2048:  return 7800;
          case 4096:  return 7800;
          case 8192:  return 7800;
          case 16384: return 7800;
          default:    return -1;
        }
      }(m_organization.density);

      int density_id = [](int density_Mb) -> int {
        switch (density_Mb) {
          //! This is related to density of bank, the refresh interval, must be modified to reflect
          //! the correct value
          case 256 :  return 0;
          case 512:   return 1;
          case 1024:  return 1;
          case 2048:  return 2;
          case 4096:  return 3;
          case 8192:  return 4;
          case 16384: return 5;
          default:    return -1;
        }
      }(m_organization.density);

      m_timing_vals("nRFC")  = JEDEC_rounding(tRFC_TABLE[0][density_id], tCK_ps);
      m_timing_vals("nREFI") = JEDEC_rounding(tREFI_BASE, tCK_ps);

      // Overwrite timing parameters with any user-provided value
      // Rate and tCK should not be overwritten
      for (int i = 1; i < m_timings.size() - 1; i++) {
        auto timing_name = std::string(m_timings(i));

        if (auto provided_timing = param_group("timing").param<int>(timing_name).optional()) {
          // Check if the user specifies in the number of cycles (e.g., nRCD)
          m_timing_vals(i) = *provided_timing;
        } else if (auto provided_timing = param_group("timing").param<float>(timing_name.replace(0, 1, "t")).optional()) {
          // Check if the user specifies in nanoseconds (e.g., tRCD)
          m_timing_vals(i) = JEDEC_rounding(*provided_timing, tCK_ps);
        }
      }

      // Check if there is any uninitialized timings
      for (int i = 0; i < m_timing_vals.size(); i++) {
        if (m_timing_vals(i) == -1) {
          throw ConfigurationError("In \"{}\", timing {} is not specified!", get_name(), m_timings(i));
        }
      }

      // Set read latency
      m_read_latency = m_timing_vals("nCL") + m_timing_vals("nBL");

      // Populate the timing constraints
      #define V(timing) (m_timing_vals(timing))
      populate_timingcons(this, {
          /*** Channel ***/
          // CAS <-> CAS
          /// Data bus occupancy
          {.level = "channel", .preceding = {"RD", "RDA"}, .following = {"RD", "RDA"}, .latency = V("nBL")}, // Row buffer
          {.level = "channel", .preceding = {"WR", "WRA"}, .following = {"WR", "WRA"}, .latency = V("nBL")},

          /*** Rank (or different BankGroup) ***/
          // CAS <-> CAS
          /// nCCDS is the minimal latency for column commands
          {.level = "rank", .preceding = {"RD", "RDA"}, .following = {"RD", "RDA"}, .latency = V("nCCDS")},
          {.level = "rank", .preceding = {"WR", "WRA"}, .following = {"WR", "WRA"}, .latency = V("nCCDS")},
          /// RD <-> WR, Minimum Read to Write, Assuming tWPRE = 1 tCK
          {.level = "rank", .preceding = {"RD", "RDA"}, .following = {"WR", "WRA"}, .latency = V("nCL") + V("nBL") + 2 - V("nCWL")}, // 14 + 1 + 2 - 9 = 8
          /// WR <-> RD, Minimum Read after Write
          {.level = "rank", .preceding = {"WR", "WRA"}, .following = {"RD", "RDA"}, .latency = V("nCWL") + V("nBL") + V("nWTRS")}, // 9 + 1 + 4 = 14
          /// CAS <-> CAS between sibling ranks, nCS (rank switching) is needed for new DQS
          {.level = "rank", .preceding = {"RD", "RDA"}, .following = {"RD", "RDA", "WR", "WRA"}, .latency = V("nBL") + V("nCS"), .is_sibling = true},
          {.level = "rank", .preceding = {"WR", "WRA"}, .following = {"RD", "RDA"}, .latency = V("nCL")  + V("nBL") + V("nCS") - V("nCWL"), .is_sibling = true},
          /// CAS <-> PREab
          {.level = "rank", .preceding = {"RD"}, .following = {"PREA"}, .latency = V("nRTP")},
          {.level = "rank", .preceding = {"WR"}, .following = {"PREA"}, .latency = V("nCWL") + V("nBL") + V("nWR")},
          /// RAS <-> RAS
          {.level = "rank", .preceding = {"ACT"}, .following = {"ACT"}, .latency = V("nRRDS")},
          // {.level = "rank", .preceding = {"ACT"}, .following = {"ACT"}, .latency = V("nFAW"), .window = 4},
          {.level = "rank", .preceding = {"ACT"}, .following = {"PREA"}, .latency = V("nRAS")},
          {.level = "rank", .preceding = {"PREA"}, .following = {"ACT"}, .latency = V("nRP")},
          /// RAS <-> REF
          {.level = "rank", .preceding = {"ACT"}, .following = {"REFab"}, .latency = V("nRC")},
          {.level = "rank", .preceding = {"PRE", "PREA"}, .following = {"REFab"}, .latency = V("nRP")},
          {.level = "rank", .preceding = {"RDA"}, .following = {"REFab"}, .latency = V("nRP") + V("nRTP")},
          {.level = "rank", .preceding = {"WRA"}, .following = {"REFab"}, .latency = V("nCWL") + V("nBL") + V("nWR") + V("nRP")},
          {.level = "rank", .preceding = {"REFab"}, .following = {"ACT", "PREA"}, .latency = V("nRFC")},

          /*** Same Bank Group ***/
          /// CAS <-> CAS
          {.level = "bankgroup", .preceding = {"RD", "RDA"}, .following = {"RD", "RDA"}, .latency = V("nCCDL")},
          {.level = "bankgroup", .preceding = {"WR", "WRA"}, .following = {"WR", "WRA"}, .latency = V("nCCDL")},
          {.level = "bankgroup", .preceding = {"WR", "WRA"}, .following = {"RD", "RDA"}, .latency = V("nCWL") + V("nBL") + V("nWTRL")},
          /// RAS <-> RAS
          {.level = "bankgroup", .preceding = {"ACT"}, .following = {"ACT"}, .latency = V("nRRDL")},

          /*** Bank ***/
          {.level = "bank", .preceding = {"ACT"}, .following = {"ACT"}, .latency = V("nRC")},
          {.level = "bank", .preceding = {"ACT"}, .following = {"RD", "RDA", "WR", "WRA"}, .latency = V("nRCD")},
          {.level = "bank", .preceding = {"ACT"}, .following = {"PRE"}, .latency = V("nRAS")},
          {.level = "bank", .preceding = {"PRE"}, .following = {"ACT"}, .latency = V("nRP")},
          {.level = "bank", .preceding = {"RD"},  .following = {"PRE"}, .latency = V("nRTP")},
          {.level = "bank", .preceding = {"WR"},  .following = {"PRE"}, .latency = V("nCWL") + V("nBL") + V("nWR")},
          {.level = "bank", .preceding = {"RDA"}, .following = {"ACT"}, .latency = V("nRTP") + V("nRP")},
          {.level = "bank", .preceding = {"WRA"}, .following = {"ACT"}, .latency = V("nCWL") + V("nBL") + V("nWR") + V("nRP")},
        }
      );
      #undef V

    };

    void set_actions() {
      m_actions.resize(m_levels.size(), std::vector<ActionFunc_t<Node>>(m_commands.size()));

      // Rank Actions
      m_actions[m_levels["rank"]][m_commands["PREA"]] = Lambdas::Action::Rank::PREab<DDR4>;
      m_actions[m_levels["rank"]][m_commands["REFab"]] = Lambdas::Action::Rank::REFab<DDR4>;
      m_actions[m_levels["rank"]][m_commands["REFab_end"]] = Lambdas::Action::Rank::REFab_end<DDR4>;

      // Bank actions
      m_actions[m_levels["bank"]][m_commands["ACT"]] = Lambdas::Action::Bank::ACT<DDR4>;
      m_actions[m_levels["bank"]][m_commands["PRE"]] = Lambdas::Action::Bank::PRE<DDR4>;
      m_actions[m_levels["bank"]][m_commands["RDA"]] = Lambdas::Action::Bank::PRE<DDR4>;
      m_actions[m_levels["bank"]][m_commands["WRA"]] = Lambdas::Action::Bank::PRE<DDR4>;
    };

    void set_preqs() {
      m_preqs.resize(m_levels.size(), std::vector<PreqFunc_t<Node>>(m_commands.size()));

      // Rank Actions
      m_preqs[m_levels["rank"]][m_commands["REFab"]] = Lambdas::Preq::Rank::RequireAllBanksClosed<DDR4>;

      // Bank actions
      m_preqs[m_levels["bank"]][m_commands["RD"]] = Lambdas::Preq::Bank::RequireRowOpen<DDR4>;
      m_preqs[m_levels["bank"]][m_commands["WR"]] = Lambdas::Preq::Bank::RequireRowOpen<DDR4>;
      m_preqs[m_levels["bank"]][m_commands["ACT"]] = Lambdas::Preq::Bank::RequireRowOpen<DDR4>;
      m_preqs[m_levels["bank"]][m_commands["PRE"]] = Lambdas::Preq::Bank::RequireBankClosed<DDR4>;
    };

    void set_rowhits() {
      m_rowhits.resize(m_levels.size(), std::vector<RowhitFunc_t<Node>>(m_commands.size()));

      m_rowhits[m_levels["bank"]][m_commands["RD"]] = Lambdas::RowHit::Bank::RDWR<DDR4>;
      m_rowhits[m_levels["bank"]][m_commands["WR"]] = Lambdas::RowHit::Bank::RDWR<DDR4>;
    }


    void set_rowopens() {
      m_rowopens.resize(m_levels.size(), std::vector<RowhitFunc_t<Node>>(m_commands.size()));

      m_rowopens[m_levels["bank"]][m_commands["RD"]] = Lambdas::RowOpen::Bank::RDWR<DDR4>;
      m_rowopens[m_levels["bank"]][m_commands["WR"]] = Lambdas::RowOpen::Bank::RDWR<DDR4>;
    }

    void set_powers() {

      m_drampower_enable = param<bool>("drampower_enable").default_val(false);
      
      m_structure_type   = param<int>("structure_type").default_val(1);

      // V, mA, pJ/cycle, ref , https://github.com/CMU-SAFARI/VAMPIRE/blob/master/dramSpec/example.cfg
      m_activation_power = param<double>("activation_power").default_val(0.0); //(nJ)
      m_precharge_power  = param<double>("precharge_power").default_val(0.0);
      m_read_power       = param<double>("read_power").default_val(0.0);
      m_write_power      = param<double>("write_power").default_val(0.0);
      m_refresh_power    = param<double>("refresh_power").default_val(0.0);

      if (!m_drampower_enable)
        return;

      m_voltage_vals.resize(m_voltages.size(), -1);

      if (auto preset_name = param_group("voltage").param<std::string>("preset").optional()) {
        if (voltage_presets.count(*preset_name) > 0) {
          m_voltage_vals = voltage_presets.at(*preset_name);
        } else {
          throw ConfigurationError("Unrecognized voltage preset \"{}\" in {}!", *preset_name, get_name());
        }
      }

      m_current_vals.resize(m_currents.size(), -1);

      if (auto preset_name = param_group("current").param<std::string>("preset").optional()) {
        if (current_presets.count(*preset_name) > 0) {
          m_current_vals = current_presets.at(*preset_name);
        } else {
          throw ConfigurationError("Unrecognized current preset \"{}\" in {}!", *preset_name, get_name());
        }
      }

      m_power_debug = param<bool>("power_debug").default_val(false);

      // TODO: Check for multichannel configs.
      int num_channels = m_organization.count[m_levels["channel"]];
      int num_ranks = m_organization.count[m_levels["rank"]];
      m_power_stats.resize(num_channels * num_ranks);
      for (int i = 0; i < num_channels; i++) {
        for (int j = 0; j < num_ranks; j++) {
          m_power_stats[i * num_ranks + j].rank_id = i * num_ranks + j;
          m_power_stats[i * num_ranks + j].cmd_counters.resize(m_cmds_counted.size(), 0);
        }
      }

      m_powers.resize(m_levels.size(), std::vector<PowerFunc_t<Node>>(m_commands.size()));

      m_powers[m_levels["bank"]][m_commands["ACT"]] = Lambdas::Power::Bank::ACT<DDR4>;
      m_powers[m_levels["bank"]][m_commands["PRE"]] = Lambdas::Power::Bank::PRE<DDR4>;
      m_powers[m_levels["bank"]][m_commands["RD"]]  = Lambdas::Power::Bank::RD<DDR4>;
      m_powers[m_levels["bank"]][m_commands["WR"]]  = Lambdas::Power::Bank::WR<DDR4>;

      m_powers[m_levels["rank"]][m_commands["ACT"]] = Lambdas::Power::Rank::ACT<DDR4>;
      m_powers[m_levels["rank"]][m_commands["PRE"]] = Lambdas::Power::Rank::PRE<DDR4>;
      m_powers[m_levels["rank"]][m_commands["PREA"]] = Lambdas::Power::Rank::PREA<DDR4>;
      m_powers[m_levels["rank"]][m_commands["REFab"]] = Lambdas::Power::Rank::REFab<DDR4>;
      m_powers[m_levels["rank"]][m_commands["REFab_end"]] = Lambdas::Power::Rank::REFab_end<DDR4>;

      // register stats
      register_stat(s_total_background_energy).name("total_background_energy");
      register_stat(s_total_cmd_energy).name("total_cmd_energy");
      register_stat(s_total_energy).name("total_energy");

      for (auto& power_stat : m_power_stats){
        register_stat(power_stat.total_background_energy).name("total_background_energy_rank{}", power_stat.rank_id);
        register_stat(power_stat.total_cmd_energy).name("total_cmd_energy_rank{}", power_stat.rank_id);
        register_stat(power_stat.total_energy).name("total_energy_rank{}", power_stat.rank_id);
        register_stat(power_stat.act_background_energy).name("act_background_energy_rank{}", power_stat.rank_id);
        register_stat(power_stat.pre_background_energy).name("pre_background_energy_rank{}", power_stat.rank_id);
        register_stat(power_stat.active_cycles).name("active_cycles_rank{}", power_stat.rank_id);
        register_stat(power_stat.idle_cycles).name("idle_cycles_rank{}", power_stat.rank_id);
      }
    }

    void create_nodes() {
      int num_channels = m_organization.count[m_levels["channel"]];
      for (int i = 0; i < num_channels; i++) {
        Node* channel = new Node(this, nullptr, 0, i);
        m_channels.push_back(channel);
      }
    }

    void finalize() override {
      if (!m_drampower_enable)
        return;

      int num_channels = m_organization.count[m_levels["channel"]];
      int num_ranks = m_organization.count[m_levels["rank"]];
      for (int i = 0; i < num_channels; i++) {
        for (int j = 0; j < num_ranks; j++) {
          process_rank_energy(m_power_stats[i * num_ranks + j], m_channels[i]->m_child_nodes[j]);
        }
      }
    }

    void process_rank_energy(PowerStats& rank_stats, Node* rank_node) {

      double act_cmd_energy = 0;
      double pre_cmd_energy = 0;
      double rd_cmd_energy = 0;
      double wr_cmd_energy = 0;
      double ref_cmd_energy = 0;

      Lambdas::Power::Rank::finalize_rank<DDR4>(rank_node, 0, AddrVec_t(), m_clk);

      auto TS = [&](std::string_view timing) { return m_timing_vals(timing); };
      auto VE = [&](std::string_view voltage) { return m_voltage_vals(voltage); };
      auto CE = [&](std::string_view current) { return m_current_vals(current); };

      double tCK_ns = (double) TS("tCK_ps") / 1000.0;

      // Energy due to other background energies, refresh energy is also calculated here
      rank_stats.act_background_energy = (VE("VDD") * CE("IDD3N") + VE("VPP") * CE("IPP3N"))
                                            * rank_stats.active_cycles * tCK_ns / 1E3;

      rank_stats.pre_background_energy = (VE("VDD") * CE("IDD2N") + VE("VPP") * CE("IPP2N"))
                                            * rank_stats.idle_cycles * tCK_ns / 1E3;
                                          
      double energy_per_act = m_activation_power;
      double energy_per_pre = m_precharge_power;
      double energy_per_rd = m_read_power;
      double energy_per_wr = m_write_power;

      // Energy due to commands, refer to DRAMPower and VAMPIRE for the energy calculation
      ref_cmd_energy  = (VE("VDD") * (CE("IDD5B")) + VE("VPP") * (CE("IPP5B")))
                                * rank_stats.cmd_counters[m_cmds_counted("REF")] * TS("nRFC") * tCK_ns / 1E3;

      switch (m_structure_type)
      {
        case 0:
            energy_per_act = (VE("VDD") * (CE("IDD0") - CE("IDD3N")) + VE("VPP") * (CE("IPP0") - CE("IPP3N")));
            act_cmd_energy  = energy_per_act
                       * rank_stats.cmd_counters[m_cmds_counted("ACT")] * TS("nRAS") * tCK_ns / 1E3;
            pre_cmd_energy  = (VE("VDD") * (CE("IDD0") - CE("IDD2N")) + VE("VPP") * (CE("IPP0") - CE("IPP2N")))
                               * rank_stats.cmd_counters[m_cmds_counted("PRE")] * TS("nRP")  * tCK_ns / 1E3;
            rd_cmd_energy   = (VE("VDD") * (CE("IDD4R") - CE("IDD3N")) + VE("VPP") * (CE("IPP4R") - CE("IPP3N")))
                               * rank_stats.cmd_counters[m_cmds_counted("RD")] * TS("nBL") * tCK_ns / 1E3;
            wr_cmd_energy   = (VE("VDD") * (CE("IDD4W") - CE("IDD3N")) + VE("VPP") * (CE("IPP4W") - CE("IPP3N")))
                               * rank_stats.cmd_counters[m_cmds_counted("WR")] * TS("nBL") * tCK_ns / 1E3;
          break;
        case 1:
          energy_per_act =   energy_per_act * 1000; // orginal energy + tsv energy, energy is pJ
          energy_per_pre =   energy_per_pre * 1000;
          energy_per_rd  =   energy_per_rd  * 1000;
          energy_per_wr  =   energy_per_wr  * 1000;

          act_cmd_energy  = energy_per_act
           * rank_stats.cmd_counters[m_cmds_counted("ACT")] * TS("nRAS") * tCK_ns / 1E3;
          pre_cmd_energy  = energy_per_pre
                             * rank_stats.cmd_counters[m_cmds_counted("PRE")] * TS("nRP")  * tCK_ns / 1E3;
          rd_cmd_energy   = energy_per_rd
                             * rank_stats.cmd_counters[m_cmds_counted("RD")] * TS("nBL") * tCK_ns / 1E3;
          wr_cmd_energy   = energy_per_wr
                             * rank_stats.cmd_counters[m_cmds_counted("WR")] * TS("nBL") * tCK_ns / 1E3;
          break;

          default:
            break;
      }

      rank_stats.total_background_energy = rank_stats.act_background_energy + rank_stats.pre_background_energy;
      rank_stats.total_cmd_energy = act_cmd_energy
                                    + pre_cmd_energy
                                    + rd_cmd_energy
                                    + wr_cmd_energy
                                    + ref_cmd_energy;

      // std::cerr << "act_cmd_energy: " << act_cmd_energy << std::endl;
      // std::cerr << "pre_cmd_energy: " << pre_cmd_energy << std::endl;
      // std::cerr << "rd_cmd_energy: " << rd_cmd_energy << std::endl;
      // std::cerr << "wr_cmd_energy: " << wr_cmd_energy << std::endl;
      // std::cerr << "ref_cmd_energy: " << ref_cmd_energy << std::endl;

      rank_stats.total_energy = rank_stats.total_background_energy + rank_stats.total_cmd_energy;

      s_total_background_energy += rank_stats.total_background_energy;
      s_total_cmd_energy += rank_stats.total_cmd_energy;
      s_total_energy += rank_stats.total_energy;
    }
};


}        // namespace Ramulator
