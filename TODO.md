
# WIP

- Add Inspector pane.
- Mouse over to show all attributes in SVG for nodes and links?

   <g id='rowGroup' transform='translate(0, 150)'>
      <rect x='25' y='40' width='310' height='20' fill='gainsboro'/>
      <rect x='25' y='76' width='310' height='20' fill='gainsboro'/>

      <text x='30' y='30' font-size='18px' font-weight='bold' fill='crimson' text-anchor='middle'>
         <tspan x='100'>Sales</tspan>
         <tspan x='200'>Expenses</tspan>
         <tspan x='300'>Net</tspan>
      </text>

      <text x='30' y='30' font-size='18px' text-anchor='middle'>
         <tspan x='30' dy='1.5em' font-weight='bold' fill='crimson' text-anchor='start'>Q1</tspan>
         <tspan x='100'>$ 223</tspan>
         <tspan x='200'>$ 195</tspan>
         <tspan x='300'>$ 28</tspan>
      </text>

      <text x='30' y='30' font-size='18px' text-anchor='middle'>
         <tspan x='30' dy='2.5em' font-weight='bold' fill='crimson' text-anchor='start'>Q2</tspan>
         <tspan x='100'>$ 183</tspan>
         <tspan x='200'>$ 70</tspan>
         <tspan x='300'>$ 113</tspan>
      </text>

      <text x='30' y='30' font-size='18px' text-anchor='middle'>
         <tspan x='30' dy='3.5em' font-weight='bold' fill='crimson' text-anchor='start'>Q3</tspan>
         <tspan x='100'>$ 277</tspan>
         <tspan x='200'>$ 88</tspan>
         <tspan x='300'>$ 189</tspan>
      </text>

      <text x='30' y='30' font-size='18px' text-anchor='middle'>
         <tspan x='30' dy='4.5em' font-weight='bold' fill='crimson' text-anchor='start'>Q4</tspan>
         <tspan x='100'>$ 402</tspan>
         <tspan x='200'>$ 133</tspan>
         <tspan x='300'>$ 269</tspan>
      </text>
   </g>

- Optimise repulsive forces with octree.

- Use 3 dimensions for raw triples graph. (On what basis, I know not.)
- Maybe add random force (diminishing).
- Highlight yellow in module list when waiting for a module to download.

- Tidy the UI. 
- Collapse edit pane if not editing.
- Make SVG labels clearer with background and border (or similar).

- Report lex and parse errors with line and column.
- Highlight loaded modules that are outdated.
- Auto-stop animation after some seconds, or if no motion can be detected would be nice.
- Optimisation - send diffs between back and front ends.

- Save to file.
- File load.

- Add Clockwise and Anticlockwise link alignment fields.
- Spatial index for click detection (optimisation).
