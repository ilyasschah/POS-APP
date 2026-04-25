using Api.Commands.PromotionItemCommands;
using Api.Models;
using Api.Queries.PromotionItemQuery;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class PromotionItemsController : ControllerBase
    {
        private readonly IMediator _mediator;

        public PromotionItemsController(IMediator mediator)
        {
            _mediator = mediator;
        }

        [HttpGet("GetByPromotionId")]
        public async Task<IActionResult> GetByPromotionId([FromQuery] int promotionId, [FromQuery] int companyId)
        {
            var result = await _mediator.Send(new GetPromotionItemsByPromotionIdQuery { PromotionId = promotionId, CompanyId = companyId });
            return Ok(result);
        }

        [HttpPost("Add")]
        public async Task<IActionResult> Add([FromQuery] int companyId, [FromBody] CreateSinglePromotionItemRequest req)
        {
            var result = await _mediator.Send(new CreatePromotionItemCommand(companyId, req));
            return Ok(result);
        }

        [HttpPatch("Update")]
        public async Task<IActionResult> Update([FromQuery] int companyId, [FromBody] UpdatePromotionItemRequest req)
        {
            var result = await _mediator.Send(new UpdatePromotionItemCommand(companyId, req));
            return Ok(result);
        }

        [HttpDelete("Delete")]
        public async Task<IActionResult> Delete([FromQuery] int id, [FromQuery] int companyId)
        {
            var result = await _mediator.Send(new DeletePromotionItemCommand(id, companyId));
            return Ok(result);
        }
    }
}