# Third-Party RTL and Licenses

ChipVerilogSuite includes RTL and related material derived from the following
OpenCores projects. The repository-level MIT license does not replace or
override these upstream copyrights and licenses. Existing notices in upstream
source files must be retained.

| Component | Covered paths | Upstream source | Copyright / author | Upstream license |
| --- | --- | --- | --- | --- |
| OR1200 HP | `Src/or1200_hp/`, `Des/or1200/` | [OpenRISC 1200 HP](https://opencores.org/projects/or1200_hp) | Authors and OpenCores.org | GNU LGPL v2.1 or later, as stated in the source headers |
| Educational MIPS-16 | `Src/mips_16/`, `Des/mips_16/` | [Educational 16-bit MIPS Processor](https://opencores.org/projects/mips_16) | Doyya / fzy | GNU LGPL; the upstream project page does not specify a version |
| Double-precision FPU | `Src/double_fpu/`, `Des/double_fpu/` | [double_fpu](https://opencores.org/projects/double_fpu) | David Lundgren | GNU LGPL according to the upstream project page; individual source files retain their original permission and disclaimer notices |
| I2C controller | `Src/i2c/`, `Des/i2c/` | [I2C controller core](https://opencores.org/projects/i2c) | Richard Herveille | BSD according to the upstream project page; individual source files retain their original permission and disclaimer notices |
| Verilog CORDIC core | `Src/verilog_cordic_core/`, `Des/cordic_core/` | [Configurable CORDIC core](https://opencores.org/projects/verilog_cordic_core) | Dale Drinkard | The upstream project page and distributed source files do not specify an exact license |

The ChipVerilogSuite authors claim no ownership of the original third-party
RTL. Benchmark-specific descriptions, organization, scripts, and evaluation
material are separate contributions covered by the repository-level license
unless otherwise noted.
