using FluentValidation;
using MediatR;
using Api.Helpers;
using Api.Models;
using Api.Services;

namespace Api.Commands.ProductsCommentsCommands.Add
{
    public class AddProductCommentCommand : IRequest<ProductCommentDto>
    {
        public CreateProductCommentRequest Request { get; }

        public AddProductCommentCommand(CreateProductCommentRequest request)
        {
            Request = request;
        }

        public class AddProductCommentCommandHandler : IRequestHandler<AddProductCommentCommand, ProductCommentDto>
        {
            private readonly ProductCommentService _service;

            public AddProductCommentCommandHandler(ProductCommentService service)
            {
                _service = service;
            }

            public async Task<ProductCommentDto> Handle(AddProductCommentCommand command, CancellationToken cancellationToken)
            {
                var entity = await _service.Create(command.Request);
                return MapperProductComment.MapToProductCommentDto(entity);
            }
        }

        public class AddProductCommentCommandValidator : AbstractValidator<AddProductCommentCommand>
        {
            public AddProductCommentCommandValidator()
            {
                RuleFor(x => x.Request.ProductId).GreaterThan(0);
                RuleFor(x => x.Request.Comment).NotEmpty();
            }
        }
    }
}
