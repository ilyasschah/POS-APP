using MediatR;
using Microsoft.AspNetCore.Mvc;
using Products.Api.Commands.Promotion.Add;
using Products.Api.Commands.Promotion.Delete;
using Products.Api.Commands.Promotion.Update;
using Products.Api.Models;
using Products.Api.Queries.PromotionQuery;

namespace Products.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class PromotionsController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<PromotionDto>>> GetAll()
        {
            var result = await mediator.Send(new GetAllPromotionsQuery());
            return Ok(result);
        }

        [HttpGet("[action]/{id:int}")]
        public async Task<ActionResult<PromotionDto>> GetById(int id)
        {
            var result = await mediator.Send(new GetPromotionByIdQuery { Id = id });
            return result != null ? Ok(result) : NotFound();
        }

        [HttpGet("[action]/{name}")]
        public async Task<ActionResult<PromotionDto>> GetByName(string name)
        {
            var result = await mediator.Send(new GetPromotionByNameQuery { Name = name });
            return result != null ? Ok(result) : NotFound();
        }

        [HttpPost("[action]")]
        public async Task<ActionResult<PromotionDto>> Add([FromQuery] CreatePromotionRequest req)
        {
            var result = await mediator.Send(new AddPromotionCommand(req));
            return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
        }

        [HttpPut("[action]/{id}")]
        public async Task<IActionResult> Update(int id, [FromQuery] UpdatePromotionRequest req)
        {
            var result = await mediator.Send(new UpdatePromotionCommand(id, req));
            return result ? NoContent() : NotFound();
        }

        [HttpDelete("[action]/{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            var result = await mediator.Send(new DeletePromotionCommand(id));
            return result ? NoContent() : NotFound();
        }
    }
}