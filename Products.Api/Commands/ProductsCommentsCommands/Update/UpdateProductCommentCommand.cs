using FluentValidation;
using MediatR;
using Products.Api.Models;
using Products.Api.Services;

namespace Products.Api.Commands.ProductCommentCommands.Update
{
    public class UpdateProductCommentCommand : IRequest<bool>
    {
        public int Id { get; }
        public UpdateProductCommentRequest Request { get; }

        public UpdateProductCommentCommand(int id, UpdateProductCommentRequest request)
        {
            Id = id;
            Request = request;
        }

        public class UpdateProductCommentCommandHandler : IRequestHandler<UpdateProductCommentCommand, bool>
        {
            private readonly ProductCommentService _service;

            public UpdateProductCommentCommandHandler(ProductCommentService service)
            {
                _service = service;
            }

            public Task<bool> Handle(UpdateProductCommentCommand command, CancellationToken cancellationToken)
            {
                return _service.Update(command.Id, command.Request);
            }
        }

        public class UpdateProductCommentCommandValidator : AbstractValidator<UpdateProductCommentCommand>
        {
            public UpdateProductCommentCommandValidator()
            {
                RuleFor(x => x.Id).GreaterThan(0);
                RuleFor(x => x.Request.ProductId).GreaterThan(0);
                RuleFor(x => x.Request.Comment).NotEmpty();
            }
        }
    }
}
