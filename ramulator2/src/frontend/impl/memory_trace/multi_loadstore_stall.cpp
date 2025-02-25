#include <filesystem>
#include <fstream>
#include <functional>
#include <iostream>

#include "base/exception.h"
#include "base/request.h"
#include "frontend/frontend.h"
#include "loadstore_stall_trace.h"

namespace Ramulator {

namespace fs = std::filesystem;

class LoadStoreStallTrace : public IFrontEnd, public Implementation {
  RAMULATOR_REGISTER_IMPLEMENTATION(
      IFrontEnd, LoadStoreStallTrace, "LoadStoreStallTrace",
      "Load/Store memory address trace with stall_cycles.")

private:
  // Adding multiple cores for traces to test
  int m_num_traces = -1;
  bool m_is_debug = false;
  std::vector<LoadStoreStallCore*> m_trace_cores;
  std::string m_returned_trace_path;

  size_t m_num_expected_insts = 0;

public:
  void init() override {
    std::vector<std::string> trace_list = param<std::vector<std::string>>("traces").desc("A list of traces.").required();
    m_num_traces = trace_list.size();
    m_clock_ratio = param<uint>("clock_ratio").required();
    m_is_debug = param<bool>("debug").default_val(false);
    m_returned_trace_path = param<std::string>("returned_trace_path").desc("Path to the returned trace file.").required();

    m_num_expected_insts = param<int>("num_expected_insts").desc("Number of instructions that the frontend should execute.").required();

    // Create the cores
    for (int id = 0; id < m_num_traces; id++) {
      LoadStoreStallCore* trace_core = new LoadStoreStallCore(m_clock_ratio, id ,m_num_expected_insts,trace_list[id],m_returned_trace_path,m_is_debug);
      // trace_core->m_callback = [this](Request& req){return this->receive(req);} ;// Check to see if the request comes back
      m_trace_cores.push_back(trace_core);
    }

    m_logger = Logging::create_logger("LoadStoreStallTrace");
  };

  void tick() override {
    m_clk++;

    if(m_clk % 100000 == 0)
      m_logger->info("Frontend ticks at Clk={}", m_clk);

    for (auto core : m_trace_cores) {
        core->tick();
    }
  };

  // TODO: FIXME
  bool is_finished() override {
    for (auto core : m_trace_cores) {
      if (!(core->is_finished())){
        return false;
      }
    }
    return true;
  };

  void connect_memory_system(IMemorySystem* memory_system) override {
      for (auto core : m_trace_cores) {
      core->connect_memory_system(memory_system);
      }
  };

  int get_num_cores() override {
      return m_num_traces;
  };
};

} // namespace Ramulator