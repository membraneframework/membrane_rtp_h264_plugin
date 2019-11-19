# Membrane Multimedia Framework: RTP H264
[![CircleCI](https://circleci.com/gh/membraneframework/membrane-element-rtp-h264.svg?style=svg)](https://circleci.com/gh/membraneframework/membrane-element-rtp-h264)

This package provides elements that can be used for depayloading H.264 video.

It is part of [Membrane Multimedia Framework](https://membraneframework.org).

## Supported packetization modes

This package currently supports only
Single Nal Unit Mode and Non-Interleaved packetization modes.
Interleaved mode is not currently supported.

## Abbreviations

* DON:        Decoding Order Number
* DONB:       Decoding Order Number Base
* DOND:       Decoding Order Number Difference
* FEC:        Forward Error Correction
* FU:         Fragmentation Unit
* IDR:        Instantaneous Decoding Refresh
* IEC:        International Electrotechnical Commission
* ISO:        International Organization for Standardization
* ITU-T:      International Telecommunication Union, Telecommunication Standardization Sector
* MANE:       Media-Aware Network Element
* MTAP:       Multi-Time Aggregation Packet
* MTAP16:     MTAP with 16-bit timestamp offset
* MTAP24:     MTAP with 24-bit timestamp offset
* NAL:        Network Abstraction Layer
* NALU:       NAL Unit
* SAR:        Sample Aspect Ratio
* SEI:        Supplemental Enhancement Information
* STAP:       Single-Time Aggregation Packet
* STAP-A:     STAP type A
* STAP-B:     STAP type B
* TS:         Timestamp
* VCL:        Video Coding Layer
* VUI:        Video Usability Information


## Installation

The package can be installed by adding `membrane_element_rtp_h264` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:membrane_element_rtp_h264, "~> 0.2.0"}
  ]
end
```

The docs can be found at [HexDocs](https://hexdocs.pm/membrane_element_rtp_h264).

## Copyright and License

Copyright 2019, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

[![Software Mansion](https://membraneframework.github.io/static/logo/swm_logo_readme.png)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

Licensed under the [Apache License, Version 2.0](LICENSE)
