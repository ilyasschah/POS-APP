
using Api.Commands.PromotionCommands.Add;
using Api.Commands.PromotionCommands.Delete;
using Api.Commands.PromotionCommands.Update;
using Api.Models;
using Api.Queries.PromotionQuery;
using MediatR;
using Microsoft.AspNetCore.Mvc;
using Api.Attributes;

namespace Api.Controllers
{
    //[SwaggerVisible]
    [ApiController]
    [Route("api/[controller]")]
    public class PromotionsController : ControllerBase
    {
        private readonly IMediator _mediator;

        public PromotionsController(IMediator mediator)
        {
            _mediator = mediator;
        }
        [HttpGet("GetAll")]
        public async Task<IActionResult> GetAll([FromQuery] int companyId)
        {
            return Ok(await _mediator.Send(new GetAllPromotionsQuery { CompanyId = companyId }));
        }
        [HttpGet("GetActive")]
        public async Task<IActionResult> GetActive([FromQuery] int companyId)
        {
            return Ok(await _mediator.Send(new GetActivePromotionsQuery { CompanyId = companyId }));
        }

        [HttpPost("Add")]
        public async Task<IActionResult> Add([FromQuery] int companyId, [FromBody] CreatePromotionRequest req)
        {
            return Ok(await _mediator.Send(new CreatePromotionCommand(companyId, req)));
        }

        [HttpPut("[action]")]
        public async Task<IActionResult> Update([FromQuery] int companyId, [FromBody] UpdatePromotionRequest req)
        {
            var result = await _mediator.Send(new UpdatePromotionCommand(companyId, req));
            return result ? NoContent() : NotFound();
        }

        [HttpDelete("[action]")]
        public async Task<IActionResult> Delete(int id, [FromQuery] int companyId)
        {
            var result = await _mediator.Send(new DeletePromotionCommand(id, companyId));
            return result ? NoContent() : NotFound();
        }
    }
}
