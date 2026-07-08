using Microsoft.AspNetCore.Mvc;
using MediatR;
using Api.Queries.MenuQuery;

namespace Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class MenuController : ControllerBase
    {
        private readonly IMediator _mediator;

        public MenuController(IMediator mediator)
        {
            _mediator = mediator;
        }

        [HttpGet]
        public async Task<IActionResult> GetFullMenu([FromQuery] int companyId, [FromQuery] int warehouseId)
        {
            if (companyId <= 0 || warehouseId <= 0)
                return BadRequest(new { message = "Company ID and Warehouse ID are required." });

            var query = new GetFullMenuQuery { CompanyId = companyId, WarehouseId = warehouseId };
            var result = await _mediator.Send(query);

            return Ok(result);
        }
    }
}