# 01. Design UI/UX for Application

Using available skills, design and develop the prototype of this app for me. Ask
me further questions if it's necessary for you to design the overall feel or
themes of this project. Fan out subagents if needed, create and coordinate
subagents on your own, suitable to do the job efficiently.

## About the project

General description can be found in the @README.md file. This project aims to do
these things:

1. To automate the process at the reception desk, we need to store possible
   events that can happen, including but not restricted to

- Inwards flow: receiving packages from the courier or circulating documents
  for signage + proofs of work signed by 3 parties (proofs can be in images,
  digital signatures, or on-site signatures) i.e. between the sender, the
  receptionist, and the recipient.
  => Possible problem: circle relationship or unclear destination when
  circulate documents internally.
- Outward flow: employees send document or paperwork outside the office,
  it requires signatures from 3 parties, options of couriers for the
  receptionist to choose from and track the delivery status.

1. Project notable features

- Collecting signatures from parties as proof of delivery.
- Smart routing for delivering or circulating documents within the org
- Smart native notification service to event-related personnel (e.g., notify
  the recipient of a package arrived at the reception, or create a ticket
  sending packages from the company outwards, etc.)

Additional docs can be found in the @docs folder.

Do these steps sequentially:

1. Ask questions if necessary to help with the process of designing. Ask
   questions like how a team of designers at Figma would ask to understand the
   business and the idea of the project to give out the desired designs.
2. Research and propose the system of pages that this project would need.
3. Understand that this project promotes customizations through YAML config files
   @blueprints/ (examples of these can be found at @blueprints/examples/ , though
   if might not be the final form of these config files). Start reasoning and
   give me your thoughts, and suggestion on the overall UI/UX design decisions.
4. Then, with my approval crafte your designing system using these configuration
   files and then using them in the nuxt.js application @aethel-view/
