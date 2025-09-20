using MediatR;
using Microsoft.AspNetCore.Mvc;
using Products.Api.Commands.ProductsCommentsCommands.Add;
using Products.Api.Commands.ProductsCommentsCommands.Delete;
using Products.Api.Commands.ProductsCommentsCommands.Update;
using Products.Api.Models;
using Products.Api.Queries.ProductCommentsQuery;

namespace Products.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ProductCommentsController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<ProductCommentDto>>> GetAll()
        {
            var result = await mediator.Send(new GetAllProductCommentsQuery());
            return Ok(result);
        }

        [HttpGet("[action]/{id:int}")]
        public async Task<ActionResult<ProductCommentDto>> GetById(int id)
        {
            var result = await mediator.Send(new GetProductCommentByIdQuery { Id = id });
            return result is null ? NotFound() : Ok(result);
        }

        [HttpGet("[action]/{productId:int}")]
        public async Task<ActionResult<List<ProductCommentDto>>> GetByProductId(int productId)
        {
            var result = await mediator.Send(new GetProductCommentsByProductIdQuery { ProductId = productId });
            return Ok(result);
        }

        [HttpPost("[action]")]
        public async Task<ActionResult<ProductCommentDto>> Add([FromQuery] CreateProductCommentRequest req)
        {
            var result = await mediator.Send(new AddProductCommentCommand(req));
            return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
        }

        [HttpPut("[action]/{id:int}")]
        public async Task<IActionResult> Update(int id, [FromQuery] UpdateProductCommentRequest req)
        {
            var ok = await mediator.Send(new UpdateProductCommentCommand(id, req));
            return ok ? NoContent() : NotFound();
        }

        [HttpDelete("[action]/{id:int}")]
        public async Task<IActionResult> Delete(int id)
        {
            var ok = await mediator.Send(new DeleteProductCommentCommand(id));
            return ok ? NoContent() : NotFound();
        }
    }
}
