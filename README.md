# San Catello — esperienza digitale

Sito statico responsive dedicato al progetto di studio, restauro e valorizzazione digitale della scultura lignea policroma di San Catello.

URL GitHub Pages e destinazione del QR code:

**https://lange99.github.io/test.github.io/**

## Funzionamento

- La navigazione passa senza ricaricare la pagina fra Il progetto, Tavole illustrative, Video e Realtà aumentata.
- Le 19 tavole della tesi sono consultabili come galleria e in un viewer quasi fullscreen; il PDF completo resta disponibile.
- I video si aprono in un modal su desktop e direttamente su YouTube su mobile.
- La sezione Realtà aumentata confronta i modelli prima e dopo il restauro.
- Il visualizzatore 3D funziona su desktop e smartphone.
- Su Android compatibile usa WebXR o Google Scene Viewer.
- Su iPhone/iPad compatibile usa Apple Quick Look; il file USDZ viene generato dal GLB corretto, quindi il vecchio `statua.usdz` bianco non viene più caricato.
- Se il dispositivo non supporta l'AR, l'interfaccia mostra un messaggio discreto.
- L'AR richiede HTTPS; GitHub Pages lo fornisce automaticamente.

## Asset 3D

Il sito usa due asset ottimizzati:

- `statua-ar-v2.glb`: San Catello prima del restauro, 248.346 triangoli e circa 4,8 MB;
- `statua-ar-dopo.glb`: San Catello dopo il restauro, 89.916 triangoli e circa 3,9 MB.

Entrambi mantengono:

- texture colore originale incorporata;
- UV, posizioni e normali conservate in virgola mobile, senza trasformazioni di texture dipendenti dalla GPU;
- normal map volutamente esclusa per evitare differenze di shader tra GPU desktop e mobile;
- orientamento verticale nativo, senza rotazioni forzate nella pagina;
- altezza del modello pari a circa 1 unità/metro nella scena.

Il file intermedio a colori può essere rigenerato con:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\build-colored-glb.ps1 -NoNormalMap
```

La versione web è stata poi ottimizzata con [gltfpack / meshoptimizer](https://github.com/zeux/meshoptimizer):

```powershell
gltfpack -i statua-colori.glb -o statua-ar-v2.glb -si 0.12 -sp -se 0.01 -noq -r statua-ar-v2-report.json
```

## QR code

Il QR deve puntare esattamente all'URL GitHub Pages riportato sopra. In questo modo continuerà a funzionare anche dopo futuri aggiornamenti del modello o della pagina.

## Crediti tecnici

Il sito usa [`<model-viewer>`](https://github.com/google/model-viewer) di Google. L'asset è ottimizzato con meshoptimizer, Copyright © 2016–2026 Arseny Kapoulkine, distribuito con licenza MIT.
