using FluentValidation;
using MediatR;
using Products.Api.Models;
using Products.Api.Services;

namespace Products.Api.Commands.PromotionItem.Update
{
    public class UpdatePromotionItemCommand : IRequest<bool>
    {
        public int Id { get; }
        public UpdatePromotionItemRequest Request { get; }

        public UpdatePromotionItemCommand(int id, UpdatePromotionItemRequest request)
        {
            Id = id;
            Request = request;
        }

        public class UpdatePromotionItemCommandHandler : IRequestHandler<UpdatePromotionItemCommand, bool>
        {
            private readonly PromotionItemService _service;

            public UpdatePromotionItemCommandHandler(PromotionItemService service)
            {
                _service = service;
            }

            public Task<bool> Handle(UpdatePromotionItemCommand command, CancellationToken cancellationToken)
            {
                return _service.Update(command.Id, command.Request);
            }
        }

        public class UpdatePromotionItemCommandValidator : AbstractValidator<UpdatePromotionItemCommand>
        {
            public UpdatePromotionItemCommandValidator()
            {
                RuleFor(c => c.Id).GreaterThan(0);
                RuleFor(c => c.Request.Uid).GreaterThan(0);
            }
        }
    }
}