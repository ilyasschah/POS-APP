using Api.Commands.PromotionItem.Add;
using Api.Commands.PromotionItem.Delete;
using Api.Commands.PromotionItem.Update;
using Api.Models;
using Api.Queries.PromotionItemQuery;
using MediatR;
using Microsoft.AspNetCore.Mvc;
using Api.Attributes;

namespace Api.Controllers
{
    //[SwaggerVisible]
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
        public async Task<IActionResult> GetByPromotionId([FromQuery] int promotionId, [FromQuery] int companyId, CancellationToken ct = default)
        {
            var result = await _mediator.Send(new GetPromotionItemsByPromotionIdQuery { PromotionId = promotionId, CompanyId = companyId }, ct);
            return Ok(result);
        }

        [HttpPost("Add")]
        public async Task<IActionResult> Add([FromQuery] int companyId, [FromBody] CreateSinglePromotionItemRequest req, CancellationToken ct = default)
        {
            var result = await _mediator.Send(new CreatePromotionItemCommand(companyId, req), ct);
            return Ok(result);
        }

        [HttpPatch("Update")]
        public async Task<IActionResult> Update([FromQuery] int companyId, [FromBody] UpdatePromotionItemRequest req, CancellationToken ct = default)
        {
            var result = await _mediator.Send(new UpdatePromotionItemCommand(companyId, req), ct);
            return Ok(result);
        }

        [HttpDelete("Delete")]
        public async Task<IActionResult> Delete([FromQuery] int id, [FromQuery] int companyId, CancellationToken ct = default)
        {
            var result = await _mediator.Send(new DeletePromotionItemCommand(id, companyId), ct);
            return Ok(result);
        }
    }
}