## Citation
If you use this code for your research, please cite our paper(s):
- Rami Rasheedi, Nicholas Contini, Mohamed Adel Gharib, Sebastian Strempfer, Senthil Gnanasekaran, Salma Abdelzaher,
  T. Guruswamy, K. Yoshii, M. Hammer, H. Shi, Y.-S. Chen, L. Rota, D. Doering, A. Dragone, T. Zhou, and A. Miceli,
  “A 28nm multiplyaccumulate ASIC architecture for on-chip data compression in MHz frame rate x-ray and electron pixel detectors,”
  Journal of Instrumentation, vol. 20, p. P10027, Oct 2025. https://doi.org/10.1088/1748-0221/20/10/P10027

Or via bibtex

```
@article{rasheedi202528nmmultiplyaccumulateasicarchitecture,
      title={A 28nm Multiply-Accumulate {ASIC} Architecture for On-Chip Data Compression in {MHz} Frame Rate X-ray and Electron Pixel Detectors}, 
      author={\red{Rami Rasheedi} and \red{Nicholas Contini} and \red{Mohamed Adel Gharib} and \red{Sebastian Strempfer} and \red{Senthil Gnanasekaran} and \red{Salma Abdelzaher} and Tejas Guruswamy and Kazutomo Yoshii and Mike Hammer and Henry Shi and Yu-Sheng Chen and Lorenzo Rota and Dionisio Doering and Angelo Dragone and Tao Zhou and Antonino Miceli},
oi = {10.1088/1748-0221/20/10/P10027},
url = {https://doi.org/10.1088/1748-0221/20/10/P10027},
year = {2025},
month = {oct},
publisher = {IOP Publishing},
volume = {20},
number = {10},
pages = {P10027},
journal = {Journal of Instrumentation},
abstract = {Modern X-ray detector systems urgently require compact, efficient, and fast data compression schemes to handle the transmission of big data from pixel arrays, enabling frame rates in the MHz regime. In this work, a data compression ASIC that implements a streaming fixed-length lossy compression scheme is introduced and analyzed, proving the feasibility and benefits of on-chip compression. The compression scheme utilizes a vector matrix product logic, which performs a number of floating-point multiplications, additions, and accumulations. The logic is verified, synthesized, and shown to fit in the area resource available for the X-ray detector under study, which comprises 192 × 168 pixels each of 12-bit width, and having a total area of 20 mm× 20 mm, about 2 mm× 20 mm of which are available for the digital logic. Several system architectures, precisions, and compression ratios ranging from 100 to 250 were analyzed to pave the way for on-chip fixed-length compression (e.g., principal component analysis, singular value decomposition) and data reduction (e.g., azimuthal integration) for X-ray and electron detectors.}
}
}
