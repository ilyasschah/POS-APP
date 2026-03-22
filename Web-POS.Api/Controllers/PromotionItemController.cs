using MediatR;
using Microsoft.AspNetCore.Mvc;
using Api.Commands.PromotionItem.Add;
using Api.Commands.PromotionItem.Delete;
using Api.Commands.PromotionItem.Update;
using Api.Queries.PromotionItemQuery;
using Api.Models;

namespace Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class PromotionItemsController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<PromotionItemDto>>> GetAll()
        {
            var result = await mediator.Send(new GetAllPromotionItemsQuery());
            return Ok(result);
        }

        [HttpGet("[action]/{id:int}")]
        public async Task<ActionResult<PromotionItemDto>> GetById(int id)
        {
            var result = await mediator.Send(new GetPromotionItemByIdQuery { Id = id });
            return result != null ? Ok(result) : NotFound();
        }

        [HttpGet("[action]/ByPromotion/{promotionId:int}")]
        public async Task<ActionResult<List<PromotionItemDto>>> GetByPromotionId(int promotionId)
        {
            var result = await mediator.Send(new GetPromotionItemsByPromotionIdQuery { PromotionId = promotionId });
            return Ok(result);
        }

        [HttpPost("[action]")]
        public async Task<ActionResult<PromotionItemDto>> Add([FromQuery] CreatePromotionItemRequest req)
        {
            var result = await mediator.Send(new AddPromotionItemCommand(req));
            return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
        }

        [HttpPut("[action]/{id}")]
        public async Task<IActionResult> Update(int id, [FromQuery] UpdatePromotionItemRequest req)
        {
            var result = await mediator.Send(new UpdatePromotionItemCommand(id, req));
            return result ? NoContent() : NotFound();
        }

        [HttpDelete("[action]/{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            var result = await mediator.Send(new DeletePromotionItemCommand(id));
            return result ? NoContent() : NotFound();
        }
    }
}