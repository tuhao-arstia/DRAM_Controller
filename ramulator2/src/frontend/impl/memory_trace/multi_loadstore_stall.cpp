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
  int m_bandwidth_sample_time_interval = 500;
  int m_read_data_path_width = 1024;
  std::vector<LoadStoreStallCore*> m_trace_cores;
  std::string m_returned_trace_path;

  size_t m_num_expected_insts = 0;

  float s_peak_bandwidth = -1;
  float s_worst_bandwidth = -1;
  float s_average_bandwidth = -1;

public:
  void init() override {
    std::vector<std::string> trace_list = param<std::vector<std::string>>("traces").desc("A list of traces.").required();
    m_num_traces = trace_list.size();
    m_clock_ratio = param<uint>("clock_ratio").required();
    m_is_debug = param<bool>("debug").default_val(false);
    m_returned_trace_path = param<std::string>("returned_trace_path").desc("Path to the returned trace file.").required();
    m_bandwidth_sample_time_interval = param<int>("bandwidth_sample_time_interval").default_val(500);
    m_read_data_path_width = param<int>("read_data_path_width").default_val(1024);

    m_num_expected_insts = param<int>("num_expected_insts").desc("Number of instructions that the frontend should execute.").required();

    // Create the cores
    for (int id = 0; id < m_num_traces; id++) {
      LoadStoreStallCore* trace_core = new LoadStoreStallCore(m_clock_ratio, id ,m_num_expected_insts,trace_list[id],m_returned_trace_path,m_is_debug,m_bandwidth_sample_time_interval,m_read_data_path_width,"");
      // trace_core->m_callback = [this](Request& req){return this->receive(req);} ;// Check to see if the request comes back
      m_trace_cores.push_back(trace_core);
    }

    m_logger = Logging::create_logger("LoadStoreStallTrace");

    //!TODO: Shall be modified since we have to calculate the individual bandwidth for future unfairness analysis
    register_stat(s_peak_bandwidth).name("peak_bandwidth");
    register_stat(s_worst_bandwidth).name("worst_bandwidth");
    register_stat(s_average_bandwidth).name("average_bandwidth");
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

    // Take the bandwidth statistics of one each of the core
    s_average_bandwidth = 0;
    
    // Calculate the average bandwidth
    for (auto core : m_trace_cores) {
      s_average_bandwidth += core->get_average_bandwidth();
    }

    // Calculate the Peak bandwidth
    s_peak_bandwidth = 0;

    for (auto core : m_trace_cores) {
      s_peak_bandwidth += core->get_peak_bandwidth();
    }


    // Calculate the worst bandwidth
    s_worst_bandwidth = 0;

    for (auto core : m_trace_cores) {
      s_worst_bandwidth += core->get_worst_bandwidth();
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