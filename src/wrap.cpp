#include "wrap.h"

#include "defines.h"
#include "machine.h"
#include "script.h"
#include <peglib.h>

#include <coreutils/file.h>
#include <coreutils/log.h>
#include <string>

using namespace std::string_literals;

SVWrap::SVWrap(peg::SemanticValues const& s) : sv(s) {}

const char* SVWrap::c_str() const
{
    return sv.c_str();
}
std::any SVWrap::operator[](size_t i) const
{
    return sv[i];
}
std::string SVWrap::token() const
{
    return sv.token();
}

std::string_view SVWrap::token_view() const
{
    return std::string_view(sv.c_str(), sv.length());
}

const std::string& SVWrap::name() const
{
    return sv.name();
}

std::type_info const& SVWrap::type(size_t i) const
{
    return sv[i].type();
}

size_t SVWrap::size() const
{
    return sv.size();
}

std::pair<size_t, size_t> SVWrap::line_info() const
{
    return sv.line_info();
}

template <>
std::vector<std::string> SVWrap::transform() const
{
    return sv.transform<std::string>();
}
template <>
std::vector<std::string_view> SVWrap::transform() const
{
    return sv.transform<std::string_view>();
}
template <>
std::vector<double> SVWrap::transform() const
{
    return sv.transform<double>();
}

template <>
std::vector<std::any> SVWrap::transform() const
{
    return sv.transform<std::any>();
}

ParserWrapper::ParserWrapper(std::string const& s)
    : p(std::make_unique<peg::parser>(s.c_str()))
{

//    p->enable_packrat_parsing();
#if 0
    p->enable_trace([](const char* name, const char* s, size_t n,
                       const peg::SemanticValues& sv, const peg::Context& c,
                       const std::any& dt) { fmt::print("Enter {}\n", name); },
                    [](const char* name, const char* s, size_t n,
                       const peg::SemanticValues& sv, const peg::Context& c,
                       const std::any& dt,
                       size_t) { fmt::print("Leave {}\n", name); });
#endif
    p->log = [&](size_t line, size_t col, const std::string& msg) {
        // errors.push_back({line, col, msg});
        if (currentError.line > 0) {
            LOGI("Already have error");
            currentError.message = msg;
        } else {
            currentError = {line, col, msg};
        }
        fmt::printf("XXX %s in %d:%d\n", msg, line, col);
    };
}
ParserWrapper::~ParserWrapper() = default;

void ParserWrapper::packrat() const
{
    p->enable_packrat_parsing();
}

/* void ParserWrapper::fixupErrors(size_t line, std::string_view errText) */
/* { */
/*     for (auto& e : errors) { */
/*         if (!errText.empty()) e.message = std::string(errText); */
/*         e.line += (line - 1); */
/*     } */
/* } */

Error ParserWrapper::parse(std::string_view source, const char* file,
                           size_t line)
{
    try {
        currentError.line = 0;
        auto rc = p->parse_n(source.data(), source.length(), nullptr);
        if (currentError.line > 0) {
            currentError.line += (line - 1);
        }
    } catch (peg::parse_error& e) {
        fmt::print("Parse error: {}\n", e.what());
        currentError.message = e.what();
        currentError.line = line;
    }
    return currentError;
}

Error ParserWrapper::parse(std::string_view source, size_t line)
{
    return parse(source, nullptr, line);
}

Error ParserWrapper::parse(std::string_view source, std::string const& file)
{
    return parse(source, file.c_str(), 1);
}

void ParserWrapper::enter(
    const char* name,
    std::function<void(const char*, size_t, std::any&)> const& fn) const
{
    (*p)[name].enter = fn;
}

void ParserWrapper::leave(
    const char* name, std::function<void(const char*, size_t, size_t, std::any&,
                                         std::any&)> const& fn) const
{
    (*p)[name].leave = fn;
}

void ParserWrapper::action(
    const char* name, std::function<std::any(SVWrap const&)> const& fn) const
{
    (*p)[name] = [fn](peg::SemanticValues const& sv) -> std::any {
        SVWrap s(sv);
        try {
            return fn(s);
        } catch (dbz_error&) {
            LOGW("DBZ");
            return std::any();
        } catch (parse_error& e) {
            LOGD("Caught %s", e.what());
            throw peg::parse_error(e.what());
        } catch (script_error& e) {
            throw peg::parse_error(e.what());
        } catch (assert_error& e) {
            throw peg::parse_error(e.what());
        } catch (machine_error& e) {
            throw peg::parse_error(e.what());
        } catch (sym_error& e) {
            throw peg::parse_error(e.what());
        } catch (std::bad_any_cast&) {
            throw peg::parse_error("Data type error");
        } catch (utils::io_exception& e) {
            throw peg::parse_error(e.what());
        }
    };
}
