# Design Bible

## Pillars

1. **Plants feel alive.** Species look distinct, grow continuously, consume resources at different rates, and react clearly to care quality.
2. **Work is physical.** The player walks between the terminal, delivery bay, storage, workbenches, and greenhouse instead of operating the entire game from menus.
3. **Progress is calm and legible.** There are no NPC queues, failure timers, combat, hunger, or horror. The pleasure comes from observation, order, improvement, and a greener hall.
4. **A small finished loop beats a broad prototype.** Optional systems only ship when the core loop remains stable and understandable.

## Setting And Layout

The game takes place inside an isolated industrial hall with a warm, overgrown interior. The floor plan preserves the original project reference:

- Main hall: `23.5 m x 20 m`.
- Residential side wing: `7.5 m x 10 m`, attached to the upper-left half of the main hall.
- Residential department: bed, compact kitchen, refrigerator, and personal objects.
- Office department: desk, computer terminal, order management, and plant journal access.
- Storage department: shelves for soil, fertilizer, tools, pots, and delivered stock.
- Nursery department: potting benches and the active plant collection.
- Greenhouse department: a `5 m x 3 m` glass greenhouse with brighter growing conditions.
- Delivery department: a marked drone pad and package intake area on the far side of the hall.

The zones use furniture, lighting, floor wear, and sight lines rather than colored debug rectangles.

## Core Session Loop

1. Inspect current plants and the objective board.
2. Use the office terminal to order a starter, the matching soil blend, fertilizer, or equipment.
3. Watch the delivery drone enter the hall and place a crate on the delivery pad.
4. Collect the crate into the inventory and prepare a pot at a nursery bench.
5. Plant, water, and fertilize according to the species profile.
6. Observe continuous growth and react to changing moisture, nutrition, and health.
7. Harvest a healthy offshoot with secateurs once the plant is mature.
8. Sell the offshoot through the terminal's collection order.
9. Reinvest leaf currency into new species and nursery capacity.

## Plant Roster

The first release targets twelve recognizable species across different care profiles:

| Species | Group | Preferred soil | Preferred feed | Water use | Character |
| --- | --- | --- | --- | --- | --- |
| Monstera deliciosa | Foliage | Aroid mix | Foliage feed | Medium | Broad split leaves |
| Alocasia Polly | Foliage | Aroid mix | Foliage feed | High | Arrow leaves with pale veins |
| Golden pothos | Foliage | Aroid mix | Foliage feed | Medium | Trailing heart leaves |
| Snake plant | Foliage | Gritty mix | Succulent tonic | Very low | Upright striped blades |
| Peace lily | Foliage | Moist mix | Bloom feed | High | Dark leaves and white spathes |
| Boston fern | Foliage | Moist mix | Foliage feed | Very high | Dense feathered fronds |
| Lily | Ornament | Loam mix | Bloom feed | Medium-high | Tall stems and flowers |
| Sunflower | Ornament | Loam mix | Bloom feed | High | Single large flower head |
| Lavender | Herb | Gritty mix | Herb feed | Low | Fine gray-green stems |
| Mint | Herb | Moist mix | Herb feed | High | Serrated paired leaves |
| Aloe vera | Succulent | Gritty mix | Succulent tonic | Very low | Fleshy toothed rosette |
| Echeveria | Succulent | Gritty mix | Succulent tonic | Very low | Compact geometric rosette |

## Growth And Care

- Growth is continuous, not an instant stage swap. New stems, leaves, and flowers emerge progressively while the plant keeps a coherent silhouette.
- Every plant tracks moisture, nutrition, health, maturity, care streak, and offshoot progress.
- Correct soil improves care quality, recovery, and growth. Incorrect soil remains playable but slows progress and raises stress.
- Correct fertilizer produces steady nutrition. Incorrect fertilizer provides less nutrition and can temporarily stress the plant.
- Watering is press-and-hold, consumes the can reservoir, and fills moisture over time.
- Overwatering and drought both matter, but neither instantly kills a plant. Visible stress gives the player time to recover.
- Healthy mature plants build offshoot progress. Secateurs convert a ready offshoot into a sellable inventory item.
- Newly planted starters have a `5.5%` chance to develop a variegation mutation. Pale leaf sectors persist through saves, pass into harvested stock, and raise the offshoot value by `1.65x`.

## Art Direction

The visual direction is grounded low-poly realism: recognizable proportions, modeled leaf silhouettes, restrained faceting, physically plausible materials, and soft industrial daylight. The hall uses cool worn concrete and brick, while plants, warm work lights, terracotta, painted metal, and wood provide color contrast. Plants must never be represented by billboards or generic green blobs.

## Scope Boundary

The first standalone release deliberately excludes customers, employees, multiplayer, complex building placement, dozens of decorative unlocks, and a large open world. These systems would dilute the plant-care loop within the current production window.
