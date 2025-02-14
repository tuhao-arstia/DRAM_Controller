#include <filesystem>
#include <fstream>
#include <functional>
#include <iostream>

#include "base/exception.h"
#include "base/request.h"
#include "frontend/frontend.h"
#include "loadstore_stall_trace.h"

namespace Ramulator
{
  namespace fs = std::filesystem;

  LoadStoreStallCore::LoadStoreStallCore(int clk_ratio, int core_id, size_t num_expected_traces, std::string trace_path_str,bool is_debug)
  {
    m_is_debug = is_debug;
    m_num_expected_traces = num_expected_traces;
    m_core_id = core_id;
    m_clock_ratio = clk_ratio;
    m_callback = [this](Request &req)
    { return this->receive(req); }; // Check to see if the request comes back
    init_trace(trace_path_str);
  };

  void LoadStoreStallCore::tick()
  {
    m_clk++;

    if (m_current_stall_cycles > 0)
    {
      m_current_stall_cycles--;
      return;
    }

    if (m_waiting_for_request == true)
    {
      return;
    }

    if(this->is_finished() || (m_curr_trace_idx > m_trace_length)) // If the core finish executing all the traces, it no longer needs to send request
    {
      return;
    }

    // Send another request
    const Trace &t = m_trace[m_curr_trace_idx];

    // addr, type, callback
    Request request(t.addr, t.is_write ? Request::Type::Write : Request::Type::Read, m_core_id,m_callback);

    bool request_sent = m_memory_system->send(request);

    if (request_sent)
    {
      if (t.is_write == false) // Stall only if the request is a read, since it is waiting for the request
        m_waiting_for_request = true;

      m_current_stall_cycles = t.stall_cycles;
      m_curr_trace_idx++;
      m_trace_count++;
    }
  };

  void LoadStoreStallCore::receive(Request &req)
  {
    // print Receive the request at clk cycle addr and core id
    if(m_is_debug)
      std::cerr << req.type_id <<"request received at " << m_clk << " clk cycle addr " << req.addr << " and core id " << m_core_id << std::endl;

    m_waiting_for_request = false;
    m_num_retired_traces++;
  };

  void LoadStoreStallCore::connect_memory_system(IMemorySystem *memory_system)
  {
    m_memory_system = memory_system;
  };

  void LoadStoreStallCore::init_trace(const std::string &file_path_str)
  {
    fs::path trace_path(file_path_str);
    if (!fs::exists(trace_path))
    {
      throw ConfigurationError("Trace {} does not exist!", file_path_str);
    }

    std::ifstream trace_file(trace_path);
    if (!trace_file.is_open())
    {
      throw ConfigurationError("Trace {} cannot be opened!", file_path_str);
    }

    std::string line;
    while (std::getline(trace_file, line))
    {
      std::vector<std::string> tokens;
      tokenize(tokens, line, " ");

      // cmd addr       stall_cycles
      // LD  0x12345678 3

      // TODO: Add line number here for better error messages
      if (tokens.size() != 3)
      {
        throw ConfigurationError("Trace {} format invalid!", file_path_str);
      }

      bool is_write = false;
      if (tokens[0] == "LD")
      {
        is_write = false;
      }
      else if (tokens[0] == "ST")
      {
        is_write = true;
      }
      else
      {
        throw ConfigurationError("Trace {} format invalid!", file_path_str);
      }

      Addr_t addr = -1;
      if (tokens[1].compare(0, 2, "0x") == 0 |
          tokens[1].compare(0, 2, "0X") == 0)
      {
        addr = std::stoll(tokens[1].substr(2), nullptr, 16);
      }
      else
      {
        addr = std::stoll(tokens[1]);
      }

      int stall_cycles = std::stoi(tokens[2]);

      m_trace.push_back({is_write, addr, stall_cycles});
    }

    trace_file.close();

    m_trace_length = m_trace.size();
  };

  // TODO: FIXME
  bool LoadStoreStallCore::is_finished()
    {
      return (m_num_retired_traces>=m_num_expected_traces) || (m_curr_trace_idx >= m_trace_length);

    };
}; // namespace Ramulator